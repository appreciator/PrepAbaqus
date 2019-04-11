function [surfEleNode,indexEle] = Solid2Surf(elementNode,typeEle)
%AQUAS系列之-提取三维实体外表面的单元-节点组成
%李祖宇
%Email:lizuyu0091@163.com
%Last modified: April 11, 2019    
    switch typeEle
        case {'3D4'}
            idx = [1,2,4;2,3,4;3,1,4;1,3,2];
            surfEleNode = [elementNode(:,idx(1,:));elementNode(:,idx(2,:));
                           elementNode(:,idx(3,:));elementNode(:,idx(4,:))];              
        case {'3D8'}
            idx = [1,2,6,5;3,4,8,7;4,1,5,8;2,3,7,6;5,6,7,8;4,3,2,1];
            surfEleNode = [elementNode(:,idx(1,:));elementNode(:,idx(2,:));
                           elementNode(:,idx(3,:));elementNode(:,idx(4,:));
                           elementNode(:,idx(5,:));elementNode(:,idx(6,:))];            
    end    
    [~,~,indexn] = unique(sort(surfEleNode,2),'rows'); %无重复的即为外表面
    [n,xout]=hist(indexn,unique(indexn));
    indexSurf = ismember(indexn,xout(n==1));
    surfEleNode = surfEleNode(indexSurf,:); %外表面的单元-节点组成
    nEle = size(elementNode,1);
    indexEle = mod(find(indexSurf),nEle);
    indexEle(indexEle==0) = nEle; %对应的单元编号(含重复值)    
end