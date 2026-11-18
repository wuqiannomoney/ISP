function m = calc_iq_metrics(RGB_in, RGB_out, RGB_gt, roi)
% CALC_IQ_METRICS  纯基础 MATLAB 实现 PSNR / SSIM 与暗区降噪率评测
    mse_in  = mean((RGB_in(:)  - RGB_gt(:)).^2);
    mse_out = mean((RGB_out(:) - RGB_gt(:)).^2);
    m.psnr_in  = 10 * log10(1.0 / max(mse_in,  1e-12));
    m.psnr_out = 10 * log10(1.0 / max(mse_out, 1e-12));

    Y_in  = 0.299*RGB_in(:,:,1)  + 0.587*RGB_in(:,:,2)  + 0.114*RGB_in(:,:,3);
    Y_out = 0.299*RGB_out(:,:,1) + 0.587*RGB_out(:,:,2) + 0.114*RGB_out(:,:,3);
    Y_gt  = 0.299*RGB_gt(:,:,1)  + 0.587*RGB_gt(:,:,2)  + 0.114*RGB_gt(:,:,3);

    m.ssim_in  = calc_ssim_2d(Y_in,  Y_gt);
    m.ssim_out = calc_ssim_2d(Y_out, Y_gt);

    % 统计暗部平坦区噪声标准差改善
    patch_in  = Y_in(roi.dark_flat);
    patch_out = Y_out(roi.dark_flat);
    m.dark_noise_in  = std(patch_in(:));
    m.dark_noise_out = std(patch_out(:));
    m.dark_noise_drop_pct = (1 - m.dark_noise_out / max(m.dark_noise_in, 1e-8)) * 100;
end

function ssim_val = calc_ssim_2d(Y1, Y2)
    C1 = 0.01^2; C2 = 0.03^2;
    mu1 = ops.gauss5x5(Y1);
    mu2 = ops.gauss5x5(Y2);
    sig1_sq = max(ops.gauss5x5(Y1.^2) - mu1.^2, 0);
    sig2_sq = max(ops.gauss5x5(Y2.^2) - mu2.^2, 0);
    sig12   = ops.gauss5x5(Y1 .* Y2) - mu1 .* mu2;
    ssim_map = ((2*mu1.*mu2 + C1) .* (2*sig12 + C2)) ./ ...
               ((mu1.^2 + mu2.^2 + C1) .* (sig1_sq + sig2_sq + C2));
    ssim_val = mean(ssim_map(:));
end