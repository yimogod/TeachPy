import random
target = random.randint(1, 100)

print("shu ru  yi ge shu zi shu zi shi dian nao xiang de")


times = 1
answer = int(input())
while answer != target:
    if answer < target:
        print("xiao le")
    elif answer >target:
        print("da le")
    times+=1
    answer = int(input())


print("good", times)