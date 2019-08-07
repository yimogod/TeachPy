target = 639
print("输入一个数字猜一下我想的是什么数字. <1000以内>")

src = int(input())
while src != target:
    if src < target :
        print("小了")
    elif src > target:
        print("大了")
    src = int(input())

print("恭喜你, 真聪明. 答对了!")
