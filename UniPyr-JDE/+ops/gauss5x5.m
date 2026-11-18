function out = gauss5x5(img)
% GAUSS5X5  可分离 5-tap [1, 4, 6, 4, 1]/16 高斯平滑
    k = [1, 4, 6, 4, 1] / 16;
    [H, W, C] = size(img);
    p = ops.pad_rep(img, 2, 2);
    out = zeros(H, W, C);
    for c = 1:C
        tmp = conv2(p(:,:,c), k, 'valid');
        out(:,:,c) = conv2(tmp, k', 'valid');
    end
end