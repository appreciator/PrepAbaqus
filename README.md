# PrepAbaqus
A preprocessor for finite element analysis using Matlab, which imports model information from Abaqus *.inp files.

本程序可自动分析商业有限元软件Abaqus的inp格式模型文件，将网格、材料、位移约束、荷载、不可设计域等信息导入为Matlab变量，作为自编Matlab有限元程序的前处理器。

功能说明：
1. 支持读取平面应力的三角形、四边形单元, 以及三维实体的四面体、六面体单元
2. 支持读取集中力、均布力、重力以及非零的强制位移约束
3. 支持读取同一Part里存在的多种线弹性材料
4. 在Abaqus的Part模块中,创建名为Set-Opt的集合, 本程序即可识别出拓扑优化时的不可设计域

模型限制:
1. 仅存在一个Part,且instance为默认的dependent类型
2. Part采用同一种单元类型,比如不能同一结构里混用四面体、六面体单元
3. 建模时必须赋予Section、创建Static Step、施加荷载与位移边界条件
4. 建模时每一Section Assignment、Boundary Condition、Load的施加均创建对应Set, 此其实为ABAQUS默认操作,支持用户修改默认的Set名称
5. 仅支持读取各向线弹性材料的弹性模量、泊松比、质量密度

示例：</br>
105万四面体单元的三维实体模型，受固定位移约束与均布面荷载作用，含拓扑优化的不可设计域</br>
在Matlab 2010b中运行PrepAbaqus程序读取该Abaqus模型，耗费时间约为4.8秒</br>
系统环境：Windows7 32bit、DDR2 4G内存、酷睿2 T8100双核CPU</br>

Abaqus原始模型
![Image text](https://raw.githubusercontent.com/appreciator/PrepAbaqus/master/Examples/Example01_Abaqus.png)


导入Matlab后所绘制的模型（含位移约束、荷载信息，但未绘制）
![Image text](https://raw.githubusercontent.com/appreciator/PrepAbaqus/master/Examples/Example01_Matlab.png)
