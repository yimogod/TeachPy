import turtle

turtle.bgcolor("black")
colors = ["red", "yellow", "blue", "green"]

p = turtle.Pen()
for x in range(200):
    p.pencolor(colors[x%4])
    #p.forward(x)
    p.circle(x)
    p.left(91)
input()