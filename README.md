# PrepAbaqus
A preprocessor for finite element analysis using Matlab, which imports model information from Abaqus *.inp files.

功能说明：
1. 支持平面应力的三角形、四边形单元, 以及三维实体的四面体、六面体单元
2. 支持集中力、均布力、重力，支持非零的强制位移约束
3. 支持同一Part里存在多种线弹性材料
4. 在Part模块中,创建名为Set-Opt的集合, 即可识别出拓扑优化所需的不可设计域

模型限制:
1. 仅存在一个Part,且instance为默认的dependent类型
2. Part采用同一种单元类型,比如不能同一结构里混用四面体、六面体单元
3. 建模时每一Section Assignment、Boundary Condition、Load的施加均创建对应Set, 此其实为ABAQUS默认操作,支持用户修改默认的Set名称
4. 仅支持读取各向线弹性材料的弹性模量、泊松比、质量密度
