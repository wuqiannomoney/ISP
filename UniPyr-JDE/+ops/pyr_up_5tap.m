function out = pyr_up_5tap(img, target_hw)
% PYR_UP_5TAP  Burt-Adelson 5-tap 归一化上采样（奇偶边界保持 DC=1）
    Ht = target_hw(1); Wt = target_hw(2);
    [~, ~, C] = size(img);
    up_zero = zeros(Ht, Wt, C);
    up_zero(1:2:end, 1:2:end, :) = img;

    mask = zeros(Ht, Wt);
    mask(1:2:end, 1:2:end) = 1;
    w_norm = max(ops.gauss5x5(mask), 1e-8);

    out = ops.gauss5x5(up_zero) ./ w_norm;
end