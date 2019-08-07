print("输入一串数字,用空格分开,我会给你排好顺序啊")

src = input()
tolist = src.split(" ")
tolist.sort()
print("我排好顺序了哦", tolist)
