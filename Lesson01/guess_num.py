target = 639
print("输入一个数字猜一下我想的是什么数字.")

answer = int(input())
while answer != target:
    if answer < target:
        print("小了")
    elif answer > target:
        print("大了")
    answer = int(input())

print("恭喜你, 真聪明. 答对了!")
