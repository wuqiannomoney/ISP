function raw_norm = apply_blc(raw_in, bl, wl)
% APPLY_BLC  减黑电平并归一化到 [0,1]（保留有符号负值，供 3DNR/BNR 抵消读出噪声负半轴）
    raw_norm = (double(raw_in) - double(bl)) / double(wl - bl);
    raw_norm = min(raw_norm, 1.2); % 仅限幅极端坏点上溢，不截断负值
end