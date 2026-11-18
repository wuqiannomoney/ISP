function [a_iso, b_iso] = calibrate_ab_from_pairs(lin_noisy_list, lin_gt_list, do_plot)
% CALIBRATE_AB_FROM_PAIRS  利用真实同 ISO 图像对拟合泊松-高斯噪声模型 Var(x) = a*x + b
%   当前设置：保持 [0.02, 0.90] 分桶范围不变，仅剔除任一通道 GT > 0.95 的像素

    if nargin < 3, do_plot = true; end
% 安全线性区间 [0.03, 0.65]（给高 ISO 噪声波峰留足 3σ 缓冲带）
    edges = linspace(0.03, 0.65, 26);
    n_bins = numel(edges) - 1;

    all_x = [];
    all_diff = [];
    for k = 1:numel(lin_noisy_list)
        xn = double(lin_noisy_list{k});
        xg = double(lin_gt_list{k});

        if size(xn, 3) == 3
            % 剔除极暗截断和单通道接近饱和区
            valid_px = all(xg > 0.015 & xg < 0.72, 3);
            xn_y = 0.25*xn(:,:,1) + 0.50*xn(:,:,2) + 0.25*xn(:,:,3);
            xg_y = 0.25*xg(:,:,1) + 0.50*xg(:,:,2) + 0.25*xg(:,:,3);
            all_x    = [all_x;    xg_y(valid_px)];                  %#ok<AGROW>
            all_diff = [all_diff; xn_y(valid_px) - xg_y(valid_px)]; %#ok<AGROW>
        else
            valid_px = (xg > 0.015 & xg < 0.72);
            all_x    = [all_x;    xg(valid_px)];                  %#ok<AGROW>
            all_diff = [all_diff; xn(valid_px) - xg(valid_px)]; %#ok<AGROW>
        end
    end

    bin_x = [];
    bin_var = [];
    for b = 1:n_bins
        mask = (all_x >= edges(b)) & (all_x < edges(b+1));
        if nnz(mask) >= 500
            bin_x(end+1)   = mean(all_x(mask));   %#ok<AGROW>
            bin_var(end+1) = var(all_diff(mask)); %#ok<AGROW>
        end
    end

    if numel(bin_x) >= 2
        p = polyfit(bin_x, bin_var, 1);
        a_iso = max(p(1), 0);
        b_iso = max(p(2), 0);
    else
        a_iso = 0;
        b_iso = max(var(all_diff), 1e-10);
    end

    if do_plot && numel(bin_x) >= 2
        figure('Name', 'Poisson-Gaussian Noise Calibration');
        scatter(bin_x, bin_var, 40, 'filled'); hold on;
        plot(bin_x, a_iso * bin_x + b_iso, 'r-', 'LineWidth', 1.8);
        grid on; xlabel('Linear Intensity x'); ylabel('Noise Variance \sigma^2');
        title(sprintf('拟合结果: a = %.6g, b = %.6g (\\sigma_{read}=%.5f)', a_iso, b_iso, sqrt(b_iso)));
        legend('实测分桶方差', '线性拟合 a*x + b', 'Location', 'northwest');
    end
end