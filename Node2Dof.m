function [eleDof,nNodeDof] = Node2Dof(elementNode,typeEle)
%AQUAS系列之单元的节点号转换为自由度号
%李祖宇
%Email:lizuyu0091@163.com
%Last modified: April 11, 2019    
    switch typeEle          
        case {'PS3','PS4','PS6','PS8','PE3','PE4','PS4_NL','PS8_NL'}   
            if size(elementNode,1)==1
                eleDof = [2*elementNode-1;2*elementNode];
                eleDof = eleDof(:);
            else
                eleDof = bsxfun(@plus,kron(elementNode',2*ones(2,1)),repmat([-1;0],size(elementNode,2),1));
            end
            nNodeDof = 2;                                 
        case {'3D4','3D8','MP4','DKQ','PS4D','PS4_CSL'}
            if size(elementNode,1)==1
                eleDof = [3*elementNode-2;3*elementNode-1;3*elementNode];
                eleDof = eleDof(:);
            else
                eleDof = bsxfun(@plus,kron(elementNode',3*ones(3,1)),repmat([-2;-1;0],size(elementNode,2),1));
            end                        
            nNodeDof = 3;              
        case {'DKQ_PS4D','MP4_PS4D','DKQ_PS4D_NL'}
            if size(elementNode,1)==1
                eleDof = [6*elementNode-5;6*elementNode-4;6*elementNode-3;6*elementNode-2;6*elementNode-1;6*elementNode];
                eleDof = eleDof(:);
            else
                eleDof = bsxfun(@plus,kron(elementNode',6*ones(6,1)),repmat((-5:1:0)',size(elementNode,2),1));
            end                           
            nNodeDof = 6;             
    end    
end