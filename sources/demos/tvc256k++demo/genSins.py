import math


x=0.0
while x<=2*math.pi:
    print   (128+12 + round(math.sin(x)*(128-13)), ", " , end='', flush=True)
    x+=(2*math.pi / 237)

print()

y=math.pi/2
while y<=math.pi:
    print   ((232) - round(math.sin(y)*(240-29)), ", " , end='', flush=True)
    y+= (math.pi / 207)

while y>math.pi/2:
    print   ((232) - round(math.sin(y)*(240-29)), ", " , end='', flush=True)
    y-= (math.pi / 207)