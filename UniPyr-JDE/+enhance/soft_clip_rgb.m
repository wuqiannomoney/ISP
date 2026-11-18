function RGB_out = soft_clip_rgb(RGB_denoised, Delta_enh)
% SOFT_CLIP_RGB  保色相软截断：某通道触及 [0,1] 边界时等比例缩放增强增量
    [H, W, ~] = size(RGB_denoised);
    base = min(max(RGB_denoised, 0), 1);
    scale = ones(H, W);

    for c = 1:3
        dc = Delta_enh(:,:,c);
        rc = base(:,:,c);

        over_mask = dc > 1e-6;
        s_over = ones(H, W);
        s_over(over_mask) = min(1, (1 - rc(over_mask)) ./ dc(over_mask));

        under_mask = dc < -1e-6;
        s_under = ones(H, W);
        s_under(under_mask) = min(1, (0 - rc(under_mask)) ./ dc(under_mask));

        scale = min(scale, min(s_over, s_under));
    end

    RGB_out = min(max(base + scale .* Delta_enh, 0), 1);
end