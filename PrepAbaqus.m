function modelFEM = PrepAbaqus(varargin)
%AQUAS系列之导入ABAQUS模型文件
%李祖宇
%Email:lizuyu0091@163.com
%Last modified: April 11, 2019
%功能说明：
%1. 支持平面应力的三角形、四边形单元, 以及三维实体的四面体、六面体单元
%2. 支持集中力、均布力、重力，支持非零的强制位移约束
%3. 支持同一Part里存在多种线弹性材料
%4. 在Part模块中,创建名为Set-Opt的集合, 即可识别出拓扑优化所需的不可设计域
%模型限制:
%1. 仅存在一个Part,且instance为默认的dependent类型
%2. Part采用同一种单元类型,比如不能同一结构里混用四面体、六面体单元
%3. 建模时每一Section Assignment、Boundary Condition、Load的施加均创建对应Set,
%   此其实为ABAQUS默认操作,支持用户修改默认的Set名称
%4. 仅支持读取各向线弹性材料的弹性模量、泊松比、质量密度
    if nargin==0
        [fName,fPath] = uigetfile('*.inp','Select the ABAQUS Model File');
        fileAbaqus = strcat(fPath,fName);
    else
        fileAbaqus = varargin{1};
    end
    [fin,message] = fopen(fileAbaqus,'r');%打开inp文件
    if fin==-1
        error([message,': ',fileAbaqus]);
    end            
    
    %节点信息
    tline = fgetl(fin);%读取文件中的当前行
    while ~strncmp(tline,'*Node',5)
        tline = fgetl(fin);
    end
    tline = fgetl(fin);%读取节点信息的第一行
    tNodeCoor = textscan(tline,'%f','delimiter',',');    
    nodeCoor = textscan(fin,repmat('%f',1,numel(tNodeCoor{1})),'delimiter', ',');%批量读取节点信息
    nodeCoor = [tNodeCoor{1}';cat(2,nodeCoor{:})];
    nodeCoor(:,1) = [];%节点的坐标矩阵, 行数为nNode, 列数为nDim   
    nNode = size(nodeCoor,1);%节点数目
    disp('Node information has been imported');
    
    %单元信息    
    while ~strncmp(tline,'*Element',8)
        tline = fgetl(fin);
    end
    typeAbaqusEle = textscan(tline,'*Element, type=%s');%读取ABAQUS单元类型
    typeAbaqusEle = typeAbaqusEle{1}{1};
    switch typeAbaqusEle
        case 'CPS3'
            typeEle = 'PS3';%Tri3 - Plane Stress
        case {'CPS4','CPS4R','CPS4I'}
            typeEle = 'PS4';%Quad4 - Plane Stress
        case {'CPS8','CPS8R'}
            typeEle = 'PS8';%Quad8 - Plane Stress            
        case {'C3D4','C3D4H'}
            typeEle = '3D4';%Tetra4 - Solid
        case {'C3D8','C3D8R','C3D8H','C3D8I','C3D8RH','C3D8IH'}
            typeEle = '3D8';%Hexa8 - Solid
        otherwise
            error('Non-supported type of element');
    end
    tline = fgetl(fin);%读取单元信息的第一行
    tEleNode = textscan(tline,'%f','delimiter',',');
    elementNode = textscan(fin,repmat('%f',1,numel(tEleNode{1})),'delimiter', ',');%批量读取单元信息
    elementNode = [tEleNode{1}';cat(2,elementNode{:})];      
    elementNode(:,1) = [];%单元的节点组成矩阵, 行数为nEle, 列数为nEleNode
    nEle = size(elementNode,1);%单元数目
    disp('Element information has been imported');
    
    %自由度信息
    [~,nNodeDof] = Node2Dof(1,typeEle);%节点的自由度数
    nDof = nNode*nNodeDof;    
    
    %Section信息,仅支持Solid Section
    nSection = 0;%属性数目
    section = zeros(nEle,2);%单元的属性号
    section_tmp = cell(nEle,1);%单元的属性号
    while ~strncmp(tline,'*Elset',6)
        tline = fgetl(fin);
    end    
    while strncmp(tline,'*Elset',6) || strncmp(tline,'*Nset',5)
        while ~strncmp(tline,'*Elset',6)
            tline = fgetl(fin);
        end
        tEleSetName = textscan(tline,'*Elset, elset=%s','delimiter',',');
        tEleSetName = regexprep(tEleSetName{1}{1},{'-','_'},'');
        %读取单元集合
        tline = fgetl(fin);
        tEleSet = [];
        while ~strncmp(tline,'*',1)
            tEleSet = [tEleSet;IncreNum(cell2mat(textscan(tline,'%f','delimiter',',')))];
            tline = fgetl(fin);
        end
        eleSet.(tEleSetName) = tEleSet;
        if strcmp(tEleSetName,'Set_Opt')
            opt.fixDesEle = setdiff(1:nEle,eleSet.(tEleSetName));%不可设计域的单元编号
        end
    end  
    while ~strncmp(tline,'** Section',10)
        tline = fgetl(fin);
    end    
    while strncmp(tline,'** Section',10)
        nSection = nSection+1;
        tline = fgetl(fin);
        tSecMat = textscan(tline,'*Solid Section, elset=%s material=%s','delimiter',',');
        indexEle = eleSet.(regexprep(tSecMat{1}{1},{'-','_'},''));
        section_tmp(indexEle,1) = tSecMat{2};%Material名称
        tline = fgetl(fin);
        tSecThick = textscan(tline,'%f','delimiter',',');     
        if isnan(tSecThick{1})
            profile{nSection} = [];
        else
            profile{nSection}.thick = tSecThick{1};%截面属性:厚度
        end        
        section(indexEle,2) = nSection;%Profile编号
        tline = fgetl(fin);
    end    
    disp('Section information has been imported');
    
    %Assembly信息
    while ~strncmp(tline,'*Assembly',9)
        tline = fgetl(fin);
    end         
    while ~strncmp(tline,'*Nset',5) && ~strncmp(tline,'*Elset, elset=_',15)
        tline = fgetl(fin);
    end
    while strncmp(tline,'*Nset',5)        
        tNodeSetName = textscan(tline,'*Nset, nset=%s','delimiter',',');
        tNodeSetName = regexprep(tNodeSetName{1}{1},{'-','_'},'');
        %读取节点集合
        tline = fgetl(fin);
        tNodeSet = [];
        while ~strncmp(tline,'*',1)
            tNodeSet = [tNodeSet;IncreNum(cell2mat(textscan(tline,'%f','delimiter',',')))];
            tline = fgetl(fin);
        end
        nodeSet.(tNodeSetName) = tNodeSet;
        if strncmp(tline,'*Elset, elset=',14)
            if ~strncmp(tline,'*Elset, elset=_',15)
                tline = fgetl(fin);
                while ~strncmp(tline,'*',1)
                    tline = fgetl(fin);
                end
            end
        end
    end
    while strncmp(tline,'*Elset, elset=_',15)     
        tEleSurfSetName = textscan(tline,'*Elset, elset=%sS%f','delimiter','_'); 
        localFace = ['S',num2str(tEleSurfSetName{2})];
        tEleSurfSetName = regexprep(tEleSurfSetName{1}{1},{'-','_'},'');        
        %读取单元面集合
        tline = fgetl(fin);
        tEleSurfFaceSet = [];
        while ~strncmp(tline,'*',1)
            tEleSurfFaceSet = [tEleSurfFaceSet;IncreNum(cell2mat(textscan(tline,'%f','delimiter',',')))];
            tline = fgetl(fin);
        end       
        tEleSurfSet.(localFace) = tEleSurfFaceSet;
        if strncmp(tline,'*Surface',8)
            eleSurfSet.(tEleSurfSetName) = tEleSurfSet;
            tEleSurfSet = [];          
            tline = fgetl(fin);
            while strncmp(tline,'_',1)
                tline = fgetl(fin);
            end
        end
    end 
    disp('Assembly information has been imported');
    
    %Material信息
    nMaterial = 0;
    while ~strncmp(tline,'*Material',9)
        tline = fgetl(fin);
    end
    while strncmp(tline,'*Material',9)
        nMaterial =  nMaterial+1;
        matName = textscan(tline,'*Material, name=%s');
        indexEle = strcmp(section_tmp(:,1),matName{1}{1});
        section(indexEle,1) = nMaterial;
        tline = fgetl(fin);
        while strncmp(tline,'*Density',8) || strncmp(tline,'*Elastic',8)
            if strncmp(tline,'*Density',8)
                tline = fgetl(fin);%读取材料信息的第一行
                mat = textscan(tline,'%f','delimiter',',');
                material{nMaterial}.density_solid = mat{1};%实体材料质量密度
                material{nMaterial}.density = material{nMaterial}.density_solid;%默认计算用材料质量密度
                tline = fgetl(fin);
            elseif strncmp(tline,'*Elastic',8)
                tline = fgetl(fin);%读取材料信息的第一行
                mat = textscan(tline,'%f','delimiter',',');
                material{nMaterial}.E_solid = mat{1}(1);%实体材料弹性模量
                material{nMaterial}.E = material{nMaterial}.E_solid;%默认计算用材料弹性模量
                material{nMaterial}.poisson = mat{1}(2);%泊松比
                tline = fgetl(fin);
            end
        end
    end
    disp('Material information has been imported');
    
    %边界条件信息
    fixDof = [];
    fixDofValue = [];
    while ~strncmp(tline,'*Boundary',9)
        tline = fgetl(fin);
    end
    while strncmp(tline,'*Boundary',9)
        tline = fgetl(fin);
        while ~strncmp(tline,'**',2)
            tDispCon = textscan(tline,'%s%f%f%f','delimiter',',');         
            fixNode = nodeSet.(regexprep(tDispCon{1}{1},{'-','_'},''));
            fixDim = tDispCon{2};
            %约束自由度编号
            fixDof = [fixDof;nNodeDof*repmat(fixNode,size(fixDim))-nNodeDof+kron(fixDim,ones(size(fixNode)))];
            if isempty(tDispCon{4})
                fixValue = 0;
            else
                fixValue = tDispCon{4};
            end
            %自由度强制约束值
            fixDofValue = [fixDofValue;fixValue*ones(size(fixNode))];
            tline = fgetl(fin);
        end
        tline = fgetl(fin);
    end    
    allDof = (1:1:nDof)';
    freeDof = setdiff(allDof,fixDof);%无约束的自由度编号
    disp('Boundary Condition information has been imported');
    
    %荷载信息
    nDsLoad = 0;
    fixForce = zeros(nDof,1);%固定外荷载
    constant.accel = [];%重力加速度
    while ~strncmp(tline,'** LOADS',8)
        tline = fgetl(fin);
    end
    while ~strncmp(tline,'** Name',7)
        tline = fgetl(fin);
    end
    while strncmp(tline,'** Name',7)
        loadType = textscan(fgetl(fin),'*%s');%荷载类型
        loadType = char(loadType{1});
        switch loadType
            case 'Dsload'
                %分布力
                nDsLoad = nDsLoad+1;
                tline = fgetl(fin);         
                tLoad = textscan(tline,'%sP%f','delimiter',',');
                dsLoad{nDsLoad} = {regexprep(tLoad{1}{1},{'-','_'},''),tLoad{2}}; 
                tline = fgetl(fin);                
            case 'Cload'
                %集中力
                tline = fgetl(fin);     
                while ~strncmp(tline,'*',1)
                    tLoad = textscan(tline,'%s%f%f','delimiter',',');
                    cLoadNode = nodeSet.(regexprep(tLoad{1}{1},{'-','_'},''));
                    cLoadDim = tLoad{2};
                    cLoadDof = nNodeDof*repmat(cLoadNode,size(cLoadDim))-nNodeDof+kron(cLoadDim,ones(size(cLoadNode)));
                    fixForce(cLoadDof,1) = fixForce(cLoadDof,1)+tLoad{3}*ones(size(cLoadNode));
                    tline = fgetl(fin);
                end        
            case 'Dload'
                %重力
                tline = fgetl(fin);
                tLoad = textscan(tline,'%*s%s%f%f%f%f','delimiter',',');
                if strcmp(tLoad{1}{1},'GRAV')
                    if isempty(tLoad{5})
                        tLoad{5} = 0;
                    end
                    constant.accel = tLoad{2}*[tLoad{3:5}];
                end
            otherwise
                error('Non-supported type of load');
        end
    end     
    %Dsload的等效节点荷载
    switch typeEle
        case 'PS4'
            %Quad4 - Plane Stress
            quad4Face = [1,2,3,4;2,3,4,1];
            for iDsLoad=1:nDsLoad
                pressValue = dsLoad{iDsLoad}{2};%Line pressure value
                localFace =  fieldnames(eleSurfSet.(dsLoad{iDsLoad}{1}));
                for iLocal = 1:numel(localFace)
                    pressElement =  eleSurfSet.(dsLoad{iDsLoad}{1}).(localFace{iLocal});
                    iLFace = textscan(localFace{iLocal},'S%f');
                    pressNode = elementNode(pressElement,quad4Face(:,iLFace{1}));
                    for iPressEle = 1:numel(pressElement)
                        tPressNode = pressNode(iPressEle,:);
                        tCoor = nodeCoor(tPressNode,:);
                        vec12 = tCoor(2,:)-tCoor(1,:);
                        vecNormal = cross([0,0,-1],[vec12,0]);
                        vecPress = -vecNormal(1:2);
                        pressX = pressValue*vecPress(1)/norm(vecPress);
                        pressY = pressValue*vecPress(2)/norm(vecPress);
                        tPressEleLen = nodeCoor(tPressNode(:,2),:)-nodeCoor(tPressNode(:,1),:);
                        tPressEleLen = sqrt(sum(tPressEleLen.^2));
                        fixForce(2*tPressNode-1,1) = fixForce(2*tPressNode-1,1)+pressX*tPressEleLen/2;
                        fixForce(2*tPressNode,1) = fixForce(2*tPressNode,1)+pressY*tPressEleLen/2;
                    end
                end
            end
        case 'PS3'
            %Tri3 - Plane Stress
            tri3Face = [1,2,3;2,3,1];
            for iDsLoad=1:nDsLoad
                pressValue = dsLoad{iDsLoad}{2};%Line pressure value
                localFace =  fieldnames(eleSurfSet.(dsLoad{iDsLoad}{1}));
                for iLocal = 1:numel(localFace)
                    pressElement =  eleSurfSet.(dsLoad{iDsLoad}{1}).(localFace{iLocal});
                    iLFace = textscan(localFace{iLocal},'S%f');
                    pressNode = elementNode(pressElement,tri3Face(:,iLFace{1}));
                    for iPressEle = 1:numel(pressElement)
                        tPressNode = pressNode(iPressEle,:);
                        tCoor = nodeCoor(tPressNode,:);
                        vec12 = tCoor(2,:)-tCoor(1,:);
                        vecNormal = cross([0,0,-1],[vec12,0]);
                        vecPress = -vecNormal(1:2);
                        pressX = pressValue*vecPress(1)/norm(vecPress);
                        pressY = pressValue*vecPress(2)/norm(vecPress);
                        tPressEleLen = nodeCoor(tPressNode(:,2),:)-nodeCoor(tPressNode(:,1),:);
                        tPressEleLen = sqrt(sum(tPressEleLen.^2));
                        fixForce(2*tPressNode-1,1) = fixForce(2*tPressNode-1,1)+pressX*tPressEleLen/2;
                        fixForce(2*tPressNode,1) = fixForce(2*tPressNode,1)+pressY*tPressEleLen/2;
                    end
                end
            end            
        case 'PS8'
            %Quad8 - Plane Stress
            quad8Face = [1,2,3,4;5,6,7,8;2,3,4,1];
            for iDsLoad=1:nDsLoad
                pressure = dsLoad(2,iDsLoad);%Line pressure
                nEleSurfFaceSet =  size(eleSurfSet{dsLoad(1,iDsLoad)},2);
                for iEleSurfFace = 1:nEleSurfFaceSet
                   pressEleSurf =  eleSurfSet{dsLoad(1,iDsLoad)}{iEleSurfFace};
                   localFace = pressEleSurf(1);
                   pressElement =  pressEleSurf(2:end);
                   pressNode = element(quad8Face(:,localFace), pressElement);
                   nPressEle = size(pressElement,1);
                   for iPressEle = 1:nPressEle
                      tPressNode = pressNode(:,iPressEle); 
                      tCoor = nodeCoor(:,tPressNode);
                      vec13 = tCoor(:,3)-tCoor(:,1);%按3点共线考虑
                      vecNormal = cross([0;0;-1],[vec13;0]);
                      vecPress = -vecNormal(1:2);
                      pressX = pressure*vecPress(1)/norm(vecPress);
                      pressY = pressure*vecPress(2)/norm(vecPress);
                      tPressEleLen = ElementLen(tPressNode,nodeCoor,typeEle);
                      fixForce(2*tPressNode-1,1) = fixForce(2*tPressNode-1,1)+pressX*tPressEleLen*[1/6;2/3;1/6];
                      fixForce(2*tPressNode,1) = fixForce(2*tPressNode,1)+pressY*tPressEleLen*[1/6;2/3;1/6];
                   end
                end
            end               
        case '3D8'
            %Hexa8 - 3D Solid
            hexa8Face = [4,5,1,2,3,1;3,6,2,3,4,5;2,7,6,7,8,8;1,8,5,6,7,4];
            for iDsLoad=1:nDsLoad
                pressValue = dsLoad{iDsLoad}{2};%Face pressure value
                localFace =  fieldnames(eleSurfSet.(dsLoad{iDsLoad}{1}));
                for iLocal = 1:numel(localFace)
                    pressElement =  eleSurfSet.(dsLoad{iDsLoad}{1}).(localFace{iLocal});
                    iLFace = textscan(localFace{iLocal},'S%f');
                    pressNode = elementNode(pressElement,hexa8Face(:,iLFace{1}));                    
                    for iPressEle = 1:numel(pressElement)
                        tPressNode = pressNode(iPressEle,:);
                        tCoor = nodeCoor(tPressNode,:);
                        vec12 = tCoor(2,:)-tCoor(1,:);
                        vec14 = tCoor(4,:)-tCoor(1,:);
                        vecNormal = cross(vec12,vec14);
                        vecPress = -vecNormal;
                        pressX = pressValue*vecPress(1)/norm(vecPress);
                        pressY = pressValue*vecPress(2)/norm(vecPress);
                        pressZ = pressValue*vecPress(3)/norm(vecPress);
                        tPressEleArea = ElementVol(tPressNode,nodeCoor,'PQUAD4');
                        fixForce(3*tPressNode-2,1) = fixForce(3*tPressNode-2,1)+pressX*tPressEleArea/4;
                        fixForce(3*tPressNode-1,1) = fixForce(3*tPressNode-1,1)+pressY*tPressEleArea/4;
                        fixForce(3*tPressNode,1) = fixForce(3*tPressNode,1)+pressZ*tPressEleArea/4;
                    end
                end
            end
        case '3D4'
            %Tetra4 - Solid     
            tet4Face = [2,1,1,1;4,4,2,3;3,2,3,4];
            for iDsLoad=1:nDsLoad
                pressValue = dsLoad{iDsLoad}{2};%Face pressure value
                localFace =  fieldnames(eleSurfSet.(dsLoad{iDsLoad}{1}));
                for iLocal = 1:numel(localFace)
                    pressElement =  eleSurfSet.(dsLoad{iDsLoad}{1}).(localFace{iLocal});
                    iLFace = textscan(localFace{iLocal},'S%f');
                    pressNode = elementNode(pressElement,tet4Face(:,iLFace{1}));                    
                    for iPressEle = 1:numel(pressElement)
                        tPressNode = pressNode(iPressEle,:);
                        tCoor = nodeCoor(tPressNode,:);
                        vec12 = tCoor(2,:)-tCoor(1,:);
                        vec13 = tCoor(3,:)-tCoor(1,:);
                        vecNormal = cross(vec12,vec13);
                        vecPress = -vecNormal;
                        pressX = pressValue*vecPress(1)/norm(vecPress);
                        pressY = pressValue*vecPress(2)/norm(vecPress);
                        pressZ = pressValue*vecPress(3)/norm(vecPress);
                        tPressEleArea = ElementVol(tPressNode,nodeCoor,'TRI3');
                        fixForce(3*tPressNode-2,1) = fixForce(3*tPressNode-2,1)+pressX*tPressEleArea/3;
                        fixForce(3*tPressNode-1,1) = fixForce(3*tPressNode-1,1)+pressY*tPressEleArea/3;
                        fixForce(3*tPressNode,1) = fixForce(3*tPressNode,1)+pressZ*tPressEleArea/3;
                    end
                end
            end            
        otherwise
            error('Non-supported type of element');
    end            
    disp('Load information has been imported');
    
    %有限元网格体积
    eleVol_geo = ElementVol(elementNode,nodeCoor,typeEle);%各有限单元的体积
    totalVol_geo = sum(eleVol_geo);%有限元网格的总体积
    
    %模型坐标范围
    minX = min(nodeCoor(:,1)); maxX = max(nodeCoor(:,1)); gapX = 0.1*(maxX-minX);
    minY = min(nodeCoor(:,2)); maxY = max(nodeCoor(:,2)); gapY = 0.1*(maxY-minY);
    if size(nodeCoor,2)==2
        axisLim = [minX-gapX,maxX+gapX,minY-gapY,maxY+gapY];
    else
        minZ = min(nodeCoor(:,3)); maxZ  = max(nodeCoor(:,3)); gapZ = 0.1*(maxZ-minZ);
        axisLim = [minX-gapX,maxX+gapX,minY-gapY,maxY+gapY,minZ-gapZ,maxZ+gapZ];
    end
    
    %有限元模型构造
    modelFEM = struct('typeEle',typeEle,'nNodeDof',nNodeDof,'nNode',nNode,'nEle',nEle,'nDof',nDof,...
        'nodeCoor',nodeCoor,'elementNode',elementNode,'eleVol_geo',eleVol_geo,'totalVol_geo',totalVol_geo,...
        'section',section,'fixDof',fixDof,'fixDofValue',fixDofValue,'freeDof',freeDof,'fixForce',fixForce,...
        'axisLim',axisLim);
    modelFEM.material = material;
    modelFEM.profile = profile;
    modelFEM.constant = constant;
    
    %优化设计参数
    if exist('opt','var')
        modelFEM.opt = opt;
    end
    
    fclose(fin);  
    
    function newNum = IncreNum(num)
        if numel(num)==3 && num(3)<num(2)
            newNum = (num(1):num(3):num(2))'; 
        else
            newNum = num;
        end     
    end        
end