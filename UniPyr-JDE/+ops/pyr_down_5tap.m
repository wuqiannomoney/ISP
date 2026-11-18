function out = pyr_down_5tap(img)
% PYR_DOWN_5TAP  Burt-Adelson 5-tap 下采样
    sm = ops.gauss5x5(img);
    out = sm(1:2:end, 1:2:end, :);
end