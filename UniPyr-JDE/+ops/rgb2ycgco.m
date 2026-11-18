function ycgco = rgb2ycgco(rgb)
% RGB2YCGCO  无乘法移位型 RGB -> YCgCo 变换
    ycgco = zeros(size(rgb));
    R = rgb(:,:,1); G = rgb(:,:,2); B = rgb(:,:,3);
    ycgco(:,:,1) =  0.25 * R + 0.50 * G + 0.25 * B; % Y
    ycgco(:,:,2) = -0.25 * R + 0.50 * G - 0.25 * B; % Cg
    ycgco(:,:,3) =  0.50 * R            - 0.50 * B; % Co
end