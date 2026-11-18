function [rgb_ltm_lin, G_LTM] = apply_log_ltm(rgb_lin, G_LTM_in)
% APPLY_LOG_LTM  线性转对数大窗口平滑 LTM，输出增强后线性图及局部倍数图 G_LTM
    [H, W, ~] = size(rgb_lin);

    if nargin >= 2 && ~isempty(G_LTM_in)
        G_LTM = G_LTM_in;
    else
        L_lin = 0.299 * rgb_lin(:,:,1) + 0.587 * rgb_lin(:,:,2) + 0.114 * rgb_lin(:,:,3);
        B_log = log(max(L_lin, 1e-4));

        n_levels = 6;
        sz_hist = cell(n_levels, 1);
        for it = 1:n_levels
            sz_hist{it} = size(B_log);
            B_log = ops.pyr_down_5tap(B_log);
        end
        for it = n_levels:-1:1
            B_log = ops.pyr_up_5tap(B_log, sz_hist{it}(1:2));
        end

        B_lin = exp(B_log);
        % 基于基层统计的自适应压缩映射（暗区提亮，亮区平滑压缩）
        key_val = median(B_lin(:));
        pivot   = max(0.08, min(0.30, key_val * 1.5));
        B_target = (B_lin ./ (B_lin + pivot)) * (1.0 + pivot);
        G_LTM = min(max(B_target ./ max(B_lin, 1e-4), 0.5), 4.5);
    end

    rgb_ltm_lin = min(max(rgb_lin .* G_LTM, 0), 1);
end