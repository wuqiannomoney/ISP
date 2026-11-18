function [RGB_clean_lin, mask_obj, roi] = gen_test_scene(H, W)
% GEN_TEST_SCENE  生成含暗部纹理、亮部云彩、阶跃边与运动圆形目标的线性测试图
    [xx, yy] = meshgrid(linspace(0, 1, W), linspace(0, 1, H));
    RGB_clean_lin = zeros(H, W, 3);

    bg_r = 0.020 * (xx < 0.5) + 0.72 * (xx >= 0.5);
    bg_g = 0.025 * (xx < 0.5) + 0.78 * (xx >= 0.5);
    bg_b = 0.030 * (xx < 0.5) + 0.88 * (xx >= 0.5);

    tex_dark   = 0.015 * sin(2*pi*xx*40) .* sin(2*pi*yy*30) .* (xx < 0.45 & yy > 0.3);
    tex_bright = 0.040 * sin(2*pi*xx*25 + 2*pi*yy*20) .* (xx > 0.55 & yy < 0.7);

    dist_circle = sqrt((xx - 0.35).^2 + (yy - 0.55).^2);
    mask_obj = dist_circle < 0.14;

    RGB_clean_lin(:,:,1) = bg_r + tex_dark + tex_bright;
    RGB_clean_lin(:,:,2) = bg_g + 0.8 * tex_dark + tex_bright;
    RGB_clean_lin(:,:,3) = bg_b + 0.4 * tex_dark + tex_bright;

    RGB_clean_lin(:,:,1) = RGB_clean_lin(:,:,1) .* (~mask_obj) + 0.18 * mask_obj;
    RGB_clean_lin(:,:,2) = RGB_clean_lin(:,:,2) .* (~mask_obj) + 0.06 * mask_obj;
    RGB_clean_lin(:,:,3) = RGB_clean_lin(:,:,3) .* (~mask_obj) + 0.04 * mask_obj;
    RGB_clean_lin = min(max(RGB_clean_lin, 1e-4), 1.0);

    % 评测 ROI 掩膜：暗部平坦区
    roi.dark_flat = (xx > 0.05 & xx < 0.40) & (yy > 0.05 & yy < 0.25);
end