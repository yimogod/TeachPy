import turtle

p = turtle.Pen()
turtle.bgcolor("black")
for x in range(100):
    #如果是偶数,用红笔
    if x % 2 == 0 :
        p.pencolor("red")
    else:#否则用黑笔
        p.pencolor("yellow")

    p.forward(x)
    #p.circle(x)
    p.left(91)
input()