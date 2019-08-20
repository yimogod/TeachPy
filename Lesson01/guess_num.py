import random

target = random.randint(1, 100)
print("输入一个数字猜一下电脑的是什么数字.")

times = 1
answer = int(input())
while answer != target:
    if answer < target:
        print("小了")
    elif answer > target:
        print("大了")
    times+=1
    answer = int(input())

print("恭喜你, 真聪明. 答对了!你用来多少次呢?  " + str(times))
