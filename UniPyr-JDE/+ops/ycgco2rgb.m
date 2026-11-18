function rgb = ycgco2rgb(ycgco)
% YCGCO2RGB  无乘法移位型 YCgCo -> RGB 逆变换
    rgb = zeros(size(ycgco));
    Y = ycgco(:,:,1); Cg = ycgco(:,:,2); Co = ycgco(:,:,3);
    t = Y - Cg;
    rgb(:,:,1) = t + Co; % R
    rgb(:,:,2) = Y + Cg; % G
    rgb(:,:,3) = t - Co; % B
end