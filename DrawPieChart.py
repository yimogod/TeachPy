import matplotlib.pyplot as plt
from optparse import OptionParser

GitName2RealName = {
    "zhangshouyang": "张守阳",
    "luojianping": "骆剑平",
    "kickrooster": "陈默",
    "YINLIANG\YinLiang": "殷亮",
    "yinliang": "殷亮",
    "xujun": "徐俊",
    "zhubenliang": "朱本量",
    "YangWeizu": "杨慰祖",
    "ZhangYi": "张译",
    "zhangyi": "张译",  
    "leilei2": "雷磊",
    "Li Di": "李迪",
    "zhaoxu1": "赵旭",
    "wangqinyin": "王勤印",
    "shuiliu-pc": "税柳",
    "shuiliu": "税柳",
    "SHUILIU-PC": "税柳",
    "laiyongcong": "赖永聪",
    "mqindex": "姜哲均",
    "liuzhibin": "刘志斌",
    "lidi": "李迪",
    "聪": "赖永聪",
    "PC-FUKAI": "付楷",
    "zhaoxu": "赵旭",
    "zhanghe": "张翮",
    "dongpeili": "董沛黎",
    "Dongpeili": "董沛黎",
    "董沛黎": "董沛黎",
    "zhanglewen": "张乐文",
    "Wenbiao Hou": "侯文彪",
    "Sakyaer": "张守阳",
    "chenliang3": "陈亮",  
    "刘庆": "刘庆",
    "h34tn": "罗恒希",
    "NoahXia": "夏文涛",
    "DouYunYing": "窦云莹",
}

if __name__=="__main__":

    usage="Usage: %prog [options] input_csv_file output_png_file"

    parser = OptionParser(usage) #带参的话会把参数变量的内容作为帮助信息输出
    # parser.add_option( "-f", "--file", dest="filename", help="read picture from File", metavar="FILE", action = "store",type="string")
    # parser.add_option("-s","--save",dest="save_mold",help="save image to file or not",default = True)
    (options,args) = parser.parse_args()

    # 必须有两个个默认参数，作为输入文件名和输出文件名
    if( len(args) != 2 ):
        parser.error("incorrect number of arguments")

    csv_file_name = args[0]
    png_file_name = args[1]

    print("Get csv file name: %s" % (csv_file_name))


    #转换过的名字和错误次数
    formated_name_dict = {}

    # 读取文件
    try:
        file = open(csv_file_name, 'r', encoding='utf8')
        text_lines = file.readlines()

        for line in text_lines:
            name, errorcount = line.split("\t")
            if GitName2RealName.get(name):
                name = GitName2RealName[name]
            
            errorcount = int(errorcount)
            if not formated_name_dict.get(name):
                formated_name_dict[name] = 0
            formated_name_dict[name] = formated_name_dict[name] + errorcount
    except IOError:
        print("Error: cannot open file for input: %s" %(csv_file_name))
        quit(1)
    else:
        file.close()


    # 名字列表和错误数列表
    name_list = []
    errorcount_list = []

    for k, v in formated_name_dict.items():
        name_list.append(k)
        errorcount_list.append(v)

    # 使用微软雅黑作为中文字体
    font = {
        'family' : 'Microsoft YaHei', # 字体名
        'weight' : 'regular',         # 字体粗细
        'size'   : 14                 # 字体大小（实测只接受数字）
    }            
    plt.rc('font', **font)

    # 调整为
    tot=sum(errorcount_list)/100.0
    autopct=lambda x: "%d" % round(x*tot)

    # Plot
    plt.pie(errorcount_list, labels=name_list, autopct=autopct, shadow=False, startangle=90)

    plt.axis('equal')

    # plt.show()

    # 保存到文件
    plt.savefig(png_file_name)
