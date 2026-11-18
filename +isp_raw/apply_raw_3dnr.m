function [raw_out, W_eff, state] = apply_raw_3dnr(curr_raw, state, a_raw, b_raw, cfg_3dnr)
% APPLY_RAW_3DNR  Raw 域 IIR 3DNR (彻底取消历史帧数累计，DDR 仅存 1 张参考帧 ref_raw)
    [H, W] = size(curr_raw);
    if nargin < 5 || isempty(cfg_3dnr)
        cfg_3dnr.block_size = 16;   % 伪亮度块大小 (等效 Bayer 32x32)
        cfg_3dnr.search_r   = 3;    % 搜索半径 (等效 Bayer ±6 像素)
        cfg_3dnr.k_thresh   = 2.2;  % 运动残差敏感度
        cfg_3dnr.alpha_max  = 0.75; % 最大历史帧融合权重
    end

    % 1. 首帧初始化：无任何额外缓存，仅存一张 raw 参考帧
    if isempty(state) || isempty(state.ref_raw)
        raw_out = curr_raw;
        W_eff   = zeros(H, W);
        state.ref_raw = curr_raw;
        return;
    end

    % 2. 构造 2x2 伪亮度图 (H/2 x W/2)
    Yc = 0.25 * (curr_raw(1:2:end,1:2:end) + curr_raw(1:2:end,2:2:end) + ...
                 curr_raw(2:2:end,1:2:end) + curr_raw(2:2:end,2:2:end));
    Yr = 0.25 * (state.ref_raw(1:2:end,1:2:end) + state.ref_raw(1:2:end,2:2:end) + ...
                 state.ref_raw(2:2:end,1:2:end) + state.ref_raw(2:2:end,2:2:end));
    [H2, W2] = size(Yc);

    % 3. 块匹配搜索最优位移 (保持 Bayer 相位一致)
    B = cfg_3dnr.block_size;
    R = cfg_3dnr.search_r;
    pad_h = mod(B - mod(H2, B), B);
    pad_w = mod(B - mod(W2, B), B);
    nBh = (H2 + pad_h) / B;
    nBw = (W2 + pad_w) / B;

    best_sad = inf(nBh, nBw);
    best_dy  = zeros(nBh, nBw);
    best_dx  = zeros(nBh, nBw);

    Yr_pad = ops.pad_rep(Yr, R, R);
    for dy = -R:R
        for dx = -R:R
            Yr_shift = Yr_pad((1:H2)+R+dy, (1:W2)+R+dx);
            diff_y = abs(Yc - Yr_shift);
            diff_blk = zeros(H2 + pad_h, W2 + pad_w);
            diff_blk(1:H2, 1:W2) = diff_y;
            sad = squeeze(sum(sum(reshape(diff_blk, B, nBh, B, nBw), 1), 3));
            if dy == 0 && dx == 0, sad = sad * 0.96; end
            better = sad < best_sad;
            best_sad(better) = sad(better);
            best_dy(better)  = dy;
            best_dx(better)  = dx;
        end
    end

    mv_y = repelem(best_dy, B, B); mv_y = mv_y(1:H2, 1:W2);
    mv_x = repelem(best_dx, B, B); mv_x = mv_x(1:H2, 1:W2);
    [cc, rr] = meshgrid(1:W2, 1:H2);
    rr_w = min(max(rr + mv_y, 1), H2);
    cc_w = min(max(cc + mv_x, 1), W2);
    warp_idx = rr_w + (cc_w - 1) * H2;

    % 4. 四通道独立对齐融合，计算当前帧各区域融合权重
    raw_out   = zeros(H, W);
    alpha_sum = zeros(H2, W2);

    for r_off = 1:2
        for c_off = 1:2
            sub_curr = curr_raw(r_off:2:end, c_off:2:end);
            sub_ref  = state.ref_raw(r_off:2:end, c_off:2:end);
            sub_warp = sub_ref(warp_idx);

            res_sm = ops.gauss5x5(abs(sub_curr - sub_warp));
            sigma_raw = sqrt(max(a_raw * max(sub_warp, 0) + b_raw, 1e-10));
            alpha_ch = cfg_3dnr.alpha_max * exp(-0.5 * (res_sm ./ (0.55 * cfg_3dnr.k_thresh * sigma_raw)).^2);

            raw_out(r_off:2:end, c_off:2:end) = (1 - alpha_ch) .* sub_curr + alpha_ch .* sub_warp;
            alpha_sum = alpha_sum + 0.25 * alpha_ch;
        end
    end

    % 5. 直接把当前帧各区域自身算出来的权重归一化输出给 W_eff (零历史负担)
    W_eff_sub = min(max(alpha_sum / max(cfg_3dnr.alpha_max, 1e-6), 0), 1);
    W_eff_sub = ops.gauss5x5(W_eff_sub);

    W_eff = zeros(H, W);
    W_eff(1:2:end, 1:2:end) = W_eff_sub; W_eff(1:2:end, 2:2:end) = W_eff_sub;
    W_eff(2:2:end, 1:2:end) = W_eff_sub; W_eff(2:2:end, 2:2:end) = W_eff_sub;

    % 6. 状态写回：仅存这一张干净的 Raw 图
    state.ref_raw = raw_out;
end