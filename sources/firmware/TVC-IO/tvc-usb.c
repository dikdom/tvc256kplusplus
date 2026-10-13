#include "tusb.h"
#include "pio_usb.h"
#include <stdio.h>
#include <stdarg.h>
#include "pico/stdlib.h"
#include "TVC-IO-main-gfx.h"
#include "hardware/clocks.h"
#include <math.h>
#include "pico/multicore.h"

#if CFG_TUH_MSC
#include "ff.h"
#include "diskio_usb.h"
#endif

#include "tvc-usb.h"

#if CFG_TUH_MSC
static scsi_inquiry_resp_t inquiry_resp;
FATFS fatfs[CFG_TUH_DEVICE_MAX];
#endif

uint8_t registerInitializedUSBDevices = 0xff;
uint8_t registerUSBMouseButtons = 0x00;
mouse_move_t mouseMove;
int8_t  registerUSBMouseDWheel = 0x00;
uint8_t registerUSBMouseSpeedRead;
uint8_t registerUSBMouseSpeedWrite;
uint8_t mouseRetrievedPort = 0x00;
bool    cdc_started = false;
// mutex_t host_task_mutex;

__attribute__ ((always_inline)) inline uint32_t tusb_time_millis_api(void) {
  return to_ms_since_boot(get_absolute_time());
}


int usb_printf_old(__unused const char *fmt, ...) {
    return 0;
}

char buf[1024];
int usb_printf(const char *fmt, ...) {
    buf[0] = '\0';
    int len = 0;
    if (tud_cdc_connected()) {
        va_list args;
        va_start(args, fmt);
        len = vsnprintf(buf, sizeof(buf)-1, fmt, args);
        va_end(args);
    // if(buf[3] == 'D')
    //     return len;
    // buf[255] = 0x00;
    // if(strstr(buf, "EP 82")!=NULL)
    //     return len;
        tud_cdc_write(buf, len);
        if((len>0) && (buf[len-1] == '\n'))
            tud_cdc_write_flush();
    }
    return len;
}
absolute_time_t hf_time_stamp = 0;

void call_host_frame() {
    absolute_time_t ts = get_absolute_time();
    if(absolute_time_diff_us(hf_time_stamp, ts)>1000) {
        hf_time_stamp = ts;
        pio_usb_host_frame();
    }
}

bool usb_SOF_tick(__unused repeating_timer_t *rt) {
    pio_usb_host_frame();
    return true;
}

void main_loop_task() {
    // if(mutex_try_enter(&host_task_mutex, NULL)) {
    tuh_task();
    if(cdc_started)
        tud_task();

    //     mutex_exit(&host_task_mutex);
    // }
}

void main_loop_task_from_gfx_core() {
    tuh_task();
    if(cdc_started)
        tud_task();
}

void init_tusb_host() {
#if CFG_TUH_MSC
    msc_fat_init();
#endif
    // mutex_init(&host_task_mutex);
    // Use tuh_configure() to pass pio configuration to the host stack
    // Note: tuh_configure() must be called before
    //  pio_usb_configuration_t pio_cfg = PIO_USB_DEFAULT_CONFIG;
    pio_usb_configuration_t pio_cfg = 
        (pio_usb_configuration_t) {.pin_dp = PIN_USB_DP,    // gpio pin for DP
                                    .pio_tx_num = 1,        // pio for TX
                                    .sm_tx = 0,             // sm in pio of TX
                                    .tx_ch = 1,             // dma channel
                                    .pio_rx_num = 1,        // pio for RX
                                    .sm_rx = 1,             // sm in pio RX
                                    .sm_eop = 2,            // SM of EOPs 
                                    .alarm_pool = NULL,     // alarm pool
                                    .debug_pin_rx = -1,     // debug pin for RX
                                    .debug_pin_eop = -1,    // debug pin for eops
                                    .skip_alarm_pool = false,    // skip alarm pool 
                                    .pinout = (PIN_USB_DM < PIN_USB_DP) ?   // order of pins
                                                    PIO_USB_PINOUT_DMDP:    // (starting at pin_dm)
                                                    PIO_USB_PINOUT_DPDM     // (starting at pin_dp)
                                    }; 

    gpio_init(PIN_USB_DM);
    gpio_init(PIN_USB_DP);
    gpio_set_pulls(PIN_USB_DM, false, false);
    gpio_set_pulls(PIN_USB_DP, false, false);


    if(! tuh_configure(1, TUH_CFGID_RPI_PIO_USB_CONFIGURATION, &pio_cfg)) {
        registerInitializedUSBDevices = 0xf0;
    } else {
        registerInitializedUSBDevices = 0xfe;
    }

    // To run USB SOF interrupt in core1, init host stack for pio_usb (roothub
    // port1) on core1
    // usb_printf("H> Is active: %d\n", tuh_rhport_is_active(1));

    if((registerInitializedUSBDevices == 0xfe) && tuh_init(1)) {
        registerInitializedUSBDevices = 0x00;
    } else {
        registerInitializedUSBDevices = 0xf1;
    }
}

void init_tusb_cdc() {
    tud_init(0);
}

repeating_timer_t rt;

bool usb_timer_callback() {
    // if(mutex_try_enter(&host_task_mutex, NULL)) {
        tuh_task();
        // mutex_exit(&host_task_mutex);
    // }
    return true;
}

void init_usb_stack(bool start_cdc) {
    init_tusb_host();
    if(start_cdc) {
        init_tusb_cdc();
    }
    cdc_started = start_cdc;
}

//--------------------------------------------------------------------+
// Device CDC
//--------------------------------------------------------------------+

// Invoked when CDC interface received data from host
#if CFG_TUD_CDC
void tud_cdc_rx_cb(uint8_t itf)
{
  (void) itf;

  char buf[64];
  uint32_t count = tud_cdc_read(buf, sizeof(buf));

  // TODO control LED on keyboard of host stack
  (void) count;
}
#endif

//--------------------------------------------------------------------+
// Host hid
//--------------------------------------------------------------------+

// Invoked when device with hid interface is mounted
// Report descriptor is also available for use. tuh_hid_parse_report_descriptor()
// can be used to parse common/simple enough descriptor.
// Note: if report descriptor length > CFG_TUH_ENUMERATION_BUFSIZE, it will be skipped
// therefore report_desc = NULL, desc_len = 0
void tuh_hid_mount_cb(uint8_t dev_addr, 
                        uint8_t instance, 
                        __unused uint8_t const* desc_report, 
                        __unused uint16_t desc_len)
{

    // Interface protocol (hid_interface_protocol_enum_t)
    // const char* protocol_str[] = { "None", "Keyboard", "Mouse" };
    
    uint8_t const itf_protocol = tuh_hid_interface_protocol(dev_addr, instance);
    if(itf_protocol == 2) {
        registerInitializedUSBDevices |= 0x01;
    }

    // uint16_t vid, pid;
    // tuh_vid_pid_get(dev_addr, &vid, &pid);

    // uint8_t const interface_protocol = tuh_hid_interface_protocol(dev_addr, instance);

    // char tempbuf[256];
    // int count = sprintf(tempbuf, "[%04x:%04x][%u] HID Interface%u, Protocol = %s\r\n", vid, pid, dev_addr, instance, protocol_str[itf_protocol]);

    // tud_cdc_write(tempbuf, count);
    // tud_cdc_write_flush();

    // Receive report from boot keyboard & mouse only
    // tuh_hid_report_received_cb() will be invoked when report is available
    if ( !tuh_hid_receive_report(dev_addr, instance) )
    {
        // tud_cdc_write_str("Error: cannot request report\r\n");
    }
}

// Invoked when device with hid interface is un-mounted
void tuh_hid_umount_cb(uint8_t dev_addr, uint8_t instance)
{
    // char tempbuf[256];
    uint8_t const itf_protocol = tuh_hid_interface_protocol(dev_addr, instance);
    if(itf_protocol == 2) {
        registerInitializedUSBDevices &= ~0x01;
    }

//   int count = sprintf(tempbuf, "[%u] HID Interface%u is unmounted\r\n", dev_addr, instance);
//   tud_cdc_write(tempbuf, count);
//   tud_cdc_write_flush();
}

// send mouse report to usb device CDC
volatile uint32_t mouseUpdateXID;
volatile uint32_t mouseUpdateYID;
static uint32_t lastMouseUpdateXID = 0;
static uint32_t lastMouseUpdateYID = 0;

static void process_mouse_report(__unused uint8_t dev_addr, hid_mouse_report_t const * report)
{
    registerUSBMouseButtons = (report->buttons & MOUSE_BUTTON_LEFT ? 0x01: 0x00) |
                                (report->buttons & MOUSE_BUTTON_MIDDLE ? 0x02: 0x00) |
                                (report->buttons & MOUSE_BUTTON_RIGHT ? 0x04: 0x00);

    uint32_t updateID;      // local copy of mouseUpdateid
    double mouseSpeed = (double)(registerUSBMouseSpeedRead >> 5) + 
                            (double)(registerUSBMouseSpeedRead & 0x1f) / 32;

    int16_t packed_dx_dy;
    int32_t mmdx = 0;
    int32_t mmdy = 0;
    do {
        updateID = mouseUpdateXID;
        if(lastMouseUpdateXID != updateID) {
            mouseMove.dx_sum = 0;
            lastMouseUpdateXID = mouseUpdateXID;
        }
        mouseMove.dx_sum += report->x;
        mmdx = lround(mouseMove.dx_sum * mouseSpeed);
        if(mmdx>255)
            mmdx = 255;
        else if(mmdx<-254)
            mmdx = -254;
    } while (updateID != mouseUpdateXID);
    do {
        updateID = mouseUpdateYID;
        if(lastMouseUpdateYID != updateID) {
            mouseMove.dy_sum = 0;
            lastMouseUpdateYID = mouseUpdateYID;
        }
        mouseMove.dy_sum += report->y;
        mmdy = lround(mouseMove.dy_sum * mouseSpeed);
        if(mmdy>255)
            mmdy = 255;
        else if(mmdy<-254)
            mmdy = -254;
    } while (updateID != mouseUpdateYID);
    packed_dx_dy = (mmdx & 0xff) +
                        ((mmdy << 8) & 0xff00);
    *(int16_t *)(&mouseMove.dx) = packed_dx_dy;
}

// Invoked when received report from device via interrupt endpoint
void tuh_hid_report_received_cb(uint8_t dev_addr, uint8_t instance, uint8_t const* report, uint16_t len)
{
  (void) len;
  uint8_t const itf_protocol = tuh_hid_interface_protocol(dev_addr, instance);

//   usb_printf("report received, protocol: %02X, addr: %02X, instance: %02X, len: %d\n",itf_protocol, dev_addr, instance, len);

  switch(itf_protocol)
  {
    case HID_ITF_PROTOCOL_MOUSE:
      process_mouse_report(dev_addr, (hid_mouse_report_t const*) report );
    break;

    default: 
        break;
  }

  // continue to request to receive report
  if ( !tuh_hid_receive_report(dev_addr, instance) )
  {
    // tud_cdc_write_str("Error: cannot request report\r\n");
  }
}


// static_assert(FF_VOLUMES == CFG_TUH_DEVICE_MAX); 
#if CFG_TUH_MSC
bool inquiry_complete_cb(__unused uint8_t dev_addr, __unused tuh_msc_complete_data_t const* cb_data)
{
    if (cb_data->csw->status != 0) {
        // usb_printf("Inquiry failed\r\n");
        return false;
    }

    // Print out Vendor ID, Product ID and Rev
    // printf("%.8s %.16s rev %.4s\r\n", inquiry_resp.vendor_id, inquiry_resp.product_id, inquiry_resp.product_rev);

    // Get capacity of device
    // uint32_t const block_count = tuh_msc_get_block_count(dev_addr, cb_data->cbw->lun);
    // uint32_t const block_size = tuh_msc_get_block_size(dev_addr, cb_data->cbw->lun);

    // usb_printf("Disk Size: %lu MB\r\n", block_count / ((1024*1024)/block_size));
    // usb_printf("Block Count = %lu, Block Size: %lu\r\n", block_count, block_size);

    return true;
} 

void tuh_msc_mount_cb(uint8_t dev_addr)
{
    uint8_t pdrv = msc_map_next_pdrv(dev_addr);
    assert(pdrv < CFG_TUH_DEVICE_MAX);
    msc_fat_plug_in(pdrv);
    uint8_t const lun = 0;
    tuh_msc_inquiry(dev_addr, lun, &inquiry_resp, inquiry_complete_cb, 0);
    char path[3] = "0:";
    path[0] += pdrv;
    if ( f_mount(&fatfs[pdrv],path, 0) != FR_OK ) {
        // usb_printf("mount drive %s failed\r\n", path);
        return;
    }
    if (f_chdrive(path) != FR_OK) {
        // usb_printf("f_chdrive(%s) failed\r\n", path);
        return;
    }
    registerInitializedUSBDevices |= 0x02;
    // printf("\r\nMass Storage drive %u is mounted\r\n", pdrv);
    // printf("Run the set-date and set-time commands so file timestamps are correct\r\n\r\n");
}

void tuh_msc_umount_cb( uint8_t dev_addr)
{
    uint8_t pdrv = msc_unmap_pdrv(dev_addr);
    char path[3] = "0:";
    path[0] += pdrv;

    FRESULT fres = f_mount(NULL, path, 0); // unmount disk
    msc_fat_unplug(pdrv);
    printf("Mass Storage drive %u is unmounted (%d)\r\n", pdrv, fres);
    registerInitializedUSBDevices &= ~0x02;
}
#endif