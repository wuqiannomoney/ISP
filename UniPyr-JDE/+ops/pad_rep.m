function out = pad_rep(img, ph, pw)
% PAD_REP  边界复制填充（无工具箱依赖）
    [H, W, ~] = size(img);
    ir = [ones(1, ph), 1:H, H * ones(1, ph)];
    ic = [ones(1, pw), 1:W, W * ones(1, pw)];
    out = img(ir, ic, :);
end