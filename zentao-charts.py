import pymysql
import pandas as pd
import traceback
from pyecharts.charts import *
from pyecharts.components import Table
import pyecharts.options as opts

# 设定禅道的数据库访问信息
Zentao_connect = dict(host="192.168.31.111", user="root", passwd="123456", db="zentao")
BugType = ['Opened', 'Resolved', 'Closed', 'Activated']


##################################### 查询禅道数据库获取Bugs统计数据 ####################################
class Zentao():
    # 访问禅道数据库，读取Bug相关数据进行统计
    # __init__自动建立数据库链接
    # 请求参数为：
    #   host：禅道数据库机器IP
    #   user：禅道数据库用户名
    #   passwd：禅道数据库口令
    #   db：禅道数据库名称，默认为zentao
    # 返回参数为：
    #   数据库句柄：self.db

    # def __init__(self,host,user,passwd,db):
    def __init__(self, **db):
        # 初始化数据库连接
        # 返回数据库句柄及游标
        super().__init__()
        try:
            self.db = pymysql.connect(**db)
            self.cursor = self.db.cursor()
        except:
            traceback.print_exc()
            print("连接禅道数据库失败！")

    def __del__(self):
        # 关闭数据库连接
        class_name = self.__class__.__name__
        self.db.close()
        # print (class_name, "数据库连接被关闭！")

    def getBugSummarybyDate_Type_common(self, product_name, version, start_date, bugtype):
        ##根据创建日期进行Bug统计查询，并按照名称及内部版本号进行分组统计
        # 按照产品及版本号进行每日新开bug统计查询
        # 可以限制时间
        # 版本号按照模糊查询
        # 输入参数：
        #   product_name：产品名称
        #   version：产品版本，可用SQL模糊查询
        #   start_date：开始日期
        #   type：新开、解决、关闭、激活 ('Opened'、'Resolved'、'Closed'、'Activated')

        BugType = bugtype

        sql = "select date(zt_bug." + BugType + "Date) as od, count(*) \
            from \
                zt_bug \
            inner join \
                zt_product \
            on \
                zt_product.id = zt_bug.product \
            inner join \
                zt_build \
            on \
                zt_build.id = zt_bug.openedBuild and zt_build.name like \"" + version + "\" \
            where \
                zt_product.name = \"" + product_name + "\" and date(zt_bug." + BugType + "Date) >= \"" + start_date + "\" \
            group by od \
            order by od asc"
        try:
            data = pd.read_sql(sql, self.db)  # 执行数据库查询，结果返回DataFrame保存
            data.index = range(len(data))  # 设定DataFrame索引
            data.columns = ["Date", BugType]  # 设定DataFrame字段
            return data

        except:
            traceback.print_exc()
            print("获取禅道数据失败")

    def getBugSummarybyDate_Priority_common(self, product_name, version, start_date, priority):
        ##根据创建日期进行Bug统计查询
        # 按照版本号及优先级进行每日新开bug统计查询
        # 可以限制时间
        # 版本号按照模糊查询
        # 输入参数：
        #   product_name：产品名称
        #   version：产品版本，可用SQL模糊查询
        #   start_date：开始日期
        #   priority：Bug优先级（1-4）

        sql = "select date(zt_bug.openedDate) as od, count(*) \
            from \
                zt_bug \
            inner join \
                zt_product \
            on \
                zt_product.id = zt_bug.product \
            inner join \
                zt_build \
            on \
                zt_build.id = zt_bug.openedBuild and zt_build.name like \"" + version + "\" \
            where \
                zt_product.name = \"" + product_name + "\" and date(zt_bug.openedDate) >= \"" + start_date + "\" \
                and zt_bug.pri = \"" + priority + "\" \
            group by od \
            order by od asc"
        try:
            data = pd.read_sql(sql, self.db)  # 执行数据库查询，结果返回DataFrame保存
            data.index = range(len(data))  # 设定DataFrame索引
            data.columns = ["Date", "每日新开_" + priority]  # 设定DataFrame字段
            return data
        except:
            traceback.print_exc()
            print("获取禅道数据失败")

    def getAllNewBugSummarybyDate_Type(self, product_name, version, start_date):
        # 进行每日新开、关闭、解决、激活的Bugs的统计
        # 按日期进行列表
        # 数据存放在DataFrame中
        # 输入参数：
        #   product_name：产品名称
        #   version：产品版本，可用SQL模糊查询
        #   start_date：开始日期

        data = []
        for type in BugType:
            Bugs = self.getBugSummarybyDate_Type_common(product_name, version, start_date, type)
            if len(Bugs):
                if len(data):
                    data = pd.merge_ordered(data, Bugs, how='outer', on='Date')
                else:
                    data = Bugs
        data = data.fillna(0)

        return data

    def getTotalBugSummarybyDate_Type(self, product_name, version, start_date):
        # 进行每日累计新开、关闭、解决、激活的Bugs的统计
        # 按日期进行列表
        # 数据存放在DataFrame中
        # 输入参数：
        #   product_name：产品名称
        #   version：产品版本，可用SQL模糊查询
        #   start_date：开始日期

        Bugs = self.getAllNewBugSummarybyDate_Type(product_name, version, start_date)

        data = Bugs.iloc[:, 1:]  # 将Bugs列表中排除日期列以外的数据取出

        for i in range(1, len(data)):
            data.iloc[i] = data.iloc[i - 1] + data.iloc[i]  # 对新列表进行逐行累加，作为每日累计数

        data = pd.concat([Bugs.iloc[:, 0], data], axis=1)  # 将Bugs列表的日期并入累加后的数据列表

        return data

    def getAllNewBugSummarybyDate_Priority(self, product_name, version, start_date):
        # 按照优先级对进行每日新开、关闭、解决的Bugs的统计
        # 按日期进行列表
        # 数据存放在DataFrame中
        # 输入参数：
        #   product_name：产品名称
        #   version：产品版本，可用SQL模糊查询
        #   start_date：开始日期
        data = []
        for i in range(1, 5):
            Bugs_1 = self.getBugSummarybyDate_Priority_common(product_name, version, start_date, str(i))
            if len(Bugs_1):
                if len(data):
                    data = pd.merge_ordered(data, Bugs_1, how='outer', on='Date')
                else:
                    data = Bugs_1
        data = data.fillna(0)

        return data


##################################### 生产Bugs统计数据图表页面 ####################################

class PrintChart():
    # 通过ECharts图表方式对统计信息进行打印
    ChartTitle = ''

    def __init__(self, product_name):
        super().__init__()
        self.page = Page(page_title='测试质量评估统计-' + product_name)
        self.tab = Tab(page_title='测试质量评估统计-' + product_name)
        self.ChartTitle = product_name

    def __del__(self):
        class_name = self.__class__.__name__

    def PrintBugsBarChart(self, DataType, Bugs_Data):
        # Bugs_Date为DataFrame类型，包括Bugs每日统计数据，
        # DataFrame第一列为索引,后续各列为统计数据
        # 输出直方图页面

        bar = Bar()

        i = 0
        for cols in Bugs_Data.columns:
            # print(cols)
            data = Bugs_Data.iloc[:, i].values.tolist()  # 提取Bugs表列数据
            if i == 0:
                bar.add_xaxis(data)  # 用Bugs统计日期作为X轴
            else:
                bar.add_yaxis(cols, data)  # 用Bugs统计数据作为Y轴
            i = i + 1

        # 设置图标格式，带ZOOM选择
        bar.set_global_opts(title_opts=opts.TitleOpts(title=self.ChartTitle, subtitle=DataType), \
                            datazoom_opts=opts.DataZoomOpts(range_start=40, range_end=100))
        # bar.render(ChartTitle+".html")
        # self.page.add(bar)

        return bar

    def PrintBugsLineChart(self, DataType, Bugs_Data):
        # Bugs_Date为DataFrame类型，包括Bugs每日统计数据，
        # DataFrame第一列为索引,后续各列为统计数据
        # 输出折线图页面

        line = Line()

        i = 0
        for cols in Bugs_Data.columns:
            # print(cols)
            data = Bugs_Data.iloc[:, i].values.tolist()  # 提取Bugs表列数据
            if i == 0:
                line.add_xaxis(data)  # 用Bugs统计日期作为X轴
            else:
                line.add_yaxis(cols, data)  # 用Bugs统计数据作为Y轴
            i = i + 1

        # 设置图标格式，带ZOOM选择
        line.set_global_opts(title_opts=opts.TitleOpts(title=self.ChartTitle, subtitle=DataType), \
                             datazoom_opts=opts.DataZoomOpts(range_start=40, range_end=100))

        # line.render(ChartTitle+".html")
        # self.page.add(line)

        return line

    def PrintBugsPage(self, **Bugs):
        # 统一输出统计图表到一个页面
        # 将不同页面放到不同的Tab
        # 统一发布 html文件

        for key in Bugs:
            line = self.PrintBugsLineChart(key, Bugs[key])
            # bar = self.PrintBugsBarChart(key,Bugs[key])
            # self.tab.add(bar,key)                          #多Tab：直方图
            self.page.add(line)  # 页面多图：折线图
            # self.tab.add(line,key)                         #多Tab：折线图
            # overlap = line.overlap(bar)                    #折线图叠加直方图
            # self.tab.add(overlap,'叠加图')
        # self.tab.render(self.ChartTitle+'.html')           #生成报表页面

        return self.page


##################################### 按照日期打印Bugs统计数据 ####################################

def PrintBugsByDate(product):
    # Bug统计是对外调用接口函数
    # 输入参数：
    #   product_name：产品名称
    #   version     ：版本号，可以采用SQL模糊查询
    #   start_date  ：查询开始日期
    # 结果输出到对应的html文件中，路径为当前运行目录下

    zentao = Zentao(**Zentao_connect)  # 链接禅道数据库
    output = PrintChart(product[0])  # 初始化报表

    Bugs1 = zentao.getTotalBugSummarybyDate_Type(product[0], product[1], product[2])
    Bugs2 = zentao.getAllNewBugSummarybyDate_Priority(product[0], product[1], product[2])
    Bugs3 = zentao.getAllNewBugSummarybyDate_Type(product[0], product[1], product[2])

    Bugs_data = {'Bugs每日累计数': Bugs1, 'Bugs每日新增数(按优先级)': Bugs2, 'Bugs每日新增数': Bugs3}

    html = output.PrintBugsPage(**Bugs_data)

    return html


########################################### 主程序入口 ###########################################
if __name__ == "__main__":

    zentao = Zentao(**Zentao_connect)
    products = (  # 定义需要生成报表的产品、版本、开始查询日期
        ['日志精析中心', '3.6%', '2020-01-01'],
        ['日智速析专家', '1.%', '2020-01-01'],
        ['指标解析中心', '3.1%', '2020-01-01'],
        ['告警辨析中心', '2.3%', '2020-01-01'],
        ['数据中台', '1.%', '2020-01-01'])

    for product in products:  # 根据产品定义，循环生成对应报表
        html = PrintBugsByDate(product)
        html.render(html.page_title + '.html')
        print(product, '对应报表已完成\n')

    print('测试质量报告全部完成，请到当前目录下查看对应产品的.html文件！\n')
