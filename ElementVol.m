function vol = ElementVol(elementNode,nodeCoor,typeEle)
%AQUAS系列之单元的面积/体积计算
%李祖宇
%Email:lizuyu0091@163.com
%Last modified: April 11, 2019
    switch typeEle
        case {'PS3','PE3','TRI3'}
            %Tri3
            if isempty(elementNode)
               elementNode = [1,2,3]; 
            end
            a = nodeCoor(elementNode(:,2),:)-nodeCoor(elementNode(:,1),:);
            b = nodeCoor(elementNode(:,3),:)-nodeCoor(elementNode(:,1),:);
            vol = abs(a(:,1).*b(:,2)-a(:,2).*b(:,1))/2;          
        case {'PS4','PE4','PQUAD4','MP4','DKQ','PS4D','PS4_CSP','PS4_CSL','DKQ_NL','PS4_NL'}
            %PQuad4
            if isempty(elementNode)
               elementNode = [1,2,3,4]; 
            end            
            a = nodeCoor(elementNode(:,2),:)-nodeCoor(elementNode(:,1),:);
            b = nodeCoor(elementNode(:,4),:)-nodeCoor(elementNode(:,1),:);
            c = nodeCoor(elementNode(:,2),:)-nodeCoor(elementNode(:,3),:);
            d = nodeCoor(elementNode(:,4),:)-nodeCoor(elementNode(:,3),:);
            vol = abs(a(:,1).*b(:,2)-a(:,2).*b(:,1))/2+abs(c(:,1).*d(:,2)-c(:,2).*d(:,1))/2;  
        case {'PS8','PS8_NL'}
            %PQuad8
            elementNode = elementNode(:,1:4);%近似转换为PQuad4计算
            a = nodeCoor(elementNode(:,2),:)-nodeCoor(elementNode(:,1),:);
            b = nodeCoor(elementNode(:,4),:)-nodeCoor(elementNode(:,1),:);
            c = nodeCoor(elementNode(:,2),:)-nodeCoor(elementNode(:,3),:);
            d = nodeCoor(elementNode(:,4),:)-nodeCoor(elementNode(:,3),:);
            vol = abs(a(:,1).*b(:,2)-a(:,2).*b(:,1))/2+abs(c(:,1).*d(:,2)-c(:,2).*d(:,1))/2;            
        case {'3D4','TET4'}
            %Tetra4
            if isempty(elementNode)
               elementNode = [1,2,3,4]; 
            end            
            a = nodeCoor(elementNode(:,2),:)-nodeCoor(elementNode(:,1),:);
            b = nodeCoor(elementNode(:,3),:)-nodeCoor(elementNode(:,1),:);
            c = nodeCoor(elementNode(:,4),:)-nodeCoor(elementNode(:,1),:);
            vol = abs(a(:,1).*(b(:,2).*c(:,3)-b(:,3).*c(:,2))+...
                        b(:,1).*(a(:,3).*c(:,2)-a(:,2).*c(:,3))+...
                        c(:,1).*(a(:,2).*b(:,3)-a(:,3).*b(:,2)))/6;                        
        case {'3D8','HEXA8'}
            %Hexa8
            if isempty(elementNode)
                elementNode = [1,2,3,4,5,6,7,8];
            end
            tetraEleNode = [2,8,6,7; 1,2,4,8; 1,6,2,8; 1,5,6,8; 4,3,7,2; 4,7,8,2];
            vol = 0;
            for iTetra = 1:6
                vert = tetraEleNode(iTetra,:);
                a = nodeCoor(elementNode(:,vert(2)),:)-nodeCoor(elementNode(:,vert(1)),:);
                b = nodeCoor(elementNode(:,vert(3)),:)-nodeCoor(elementNode(:,vert(1)),:);
                c = nodeCoor(elementNode(:,vert(4)),:)-nodeCoor(elementNode(:,vert(1)),:);
                vol = vol + abs(a(:,1).*(b(:,2).*c(:,3)-b(:,3).*c(:,2))+...
                    b(:,1).*(a(:,3).*c(:,2)-a(:,2).*c(:,3))+...
                    c(:,1).*(a(:,2).*b(:,3)-a(:,3).*b(:,2)))/6;
            end  
        case {'DKQ_PS4D','MP4_PS4D','DKQ_PS4D_NL','WQUAD4'}
            %Quad4 - 3D Surf with Warping
            if isempty(elementNode)
               elementNode = [1,2,3,4]; 
            end            
            nEle = size(elementNode,1);
            vol = zeros(nEle,1);
            for iEle = 1:nEle
                eleNode = elementNode(iEle,:);
                eleNodeCoor = nodeCoor(eleNode,:);
                %整体坐标到局部坐标的转换(单元平面为局部坐标的XY平面, 且1-4中点A与2-3中点C连线为局部X轴)
                a = sum(eleNodeCoor([2;3],:)-eleNodeCoor([1;4],:),1)/2;%x_ji,y_ji,z_ji
                b = sum(eleNodeCoor([3;4],:))/2-sum(eleNodeCoor([1;4],:))/2;%x_mi,y_mi,z_mi
                cosX = a/sqrt(sum(a.^2));%[cos_xx', cos_xy', cos_xz']
                cosZ = [a(2)*b(3)-a(3)*b(2),a(3)*b(1)-a(1)*b(3),a(1)*b(2)-a(2)*b(1)];
                cosZ = cosZ/sqrt(sum(cosZ.^2));%[cos_zx', cos_zy', cos_zz']
                cosY = [cosZ(2)*cosX(3)-cosX(2)*cosZ(3),cosZ(3)*cosX(1)-cosX(3)*cosZ(1),cosZ(1)*cosX(2)-cosX(1)*cosZ(2)];%[cos_yx', cos_yy', cos_yz']
                transCos = [cosX;cosY;cosZ];
                transT1 = blkdiag(transCos,transCos,transCos,transCos);
                eleNodeCoor = eleNodeCoor';
                eleNodeCoor = reshape(transT1*eleNodeCoor(:),3,4)';%局部坐标下节点坐标 
                eleNodeCoor = eleNodeCoor(:,1:2);%剔除Z坐标以减少计算量             
                %平面坐标下的面积计算
                a = eleNodeCoor(2,:)-eleNodeCoor(1,:);
                b = eleNodeCoor(4,:)-eleNodeCoor(1,:);
                c = eleNodeCoor(2,:)-eleNodeCoor(3,:);
                d = eleNodeCoor(4,:)-eleNodeCoor(3,:);
                vol(iEle,1) = abs(a(:,1).*b(:,2)-a(:,2).*b(:,1))/2+abs(c(:,1).*d(:,2)-c(:,2).*d(:,1))/2;
            end
    end
end