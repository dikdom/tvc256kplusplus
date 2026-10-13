import math


x=0.0
while x<=2*math.pi:
    print   (50 + round(math.sin(x)*(128)), ", " , end='', flush=True)
    x+=(2*math.pi / 152 )

print()

y=0.0
while y<=2*math.pi:
    print   ((50) + round(math.sin(y)*(120)), ", " , end='', flush=True)
    y+= (2*math.pi / 166)
