%% RUN_CRVD_CALIBRATION  跑通 ISP 全流直到后端 3 层金字塔，标定每档 ISO 各层真实噪声并保存入 UniPyr-JDE
clear; clc; close all;

root_dir = fileparts(mfilename('fullpath'));
jdef_dir = fullfile(root_dir, 'UniPyr-JDE');
addpath(root_dir);
addpath(jdef_dir);

% === 1. 请修改为你本地下载好的 CRVD 目录 ===
crvd_root   = 'D:\mydata\code\matlab\datasets\CRVD';
sensor_name = 'crvd_imx385';

% === 2. 前级开关配置（与 run_full_isp.m 保持一致） ===
enable_raw_bnr    = false;  % 跳过 Raw BNR
enable_ltm        = false;  % 跳过 LTM
max_pairs_per_iso = 6;

items = isp_io.scan_crvd_dataset(crvd_root);
valid_mask = ~cellfun(@isempty, {items.clean_path});
if ~any(valid_mask), valid_mask = ~cellfun(@isempty, {items.gt_path}); end
items = items(valid_mask);

iso_list = sort(unique([items.iso]));
fprintf('检测到 CRVD 数据集 ISO 档位: %s\n', mat2str(iso_list));

[x_lut, gamma_lut] = config.gamma_curves('srgb', 1024);

n_iso = numel(iso_list);
a_raw_arr = zeros(1, n_iso); b_raw_arr = zeros(1, n_iso);
a_eff_arr = zeros(1, n_iso); b_eff_arr = zeros(1, n_iso);
layer_scale_mat = zeros(n_iso, 3);

for idx_i = 1:n_iso
    iso_val = iso_list(idx_i);
    sub_items = items([items.iso] == iso_val);
    step = max(1, floor(numel(sub_items) / max_pairs_per_iso));
    sub_items = sub_items(1:step:end);
    if numel(sub_items) > max_pairs_per_iso, sub_items = sub_items(1:max_pairs_per_iso); end

    fprintf('\n[%d/%d] 正在标定 ISO %d (抽样 %d 组)...\n', idx_i, n_iso, iso_val, numel(sub_items));

    raw_n_list = {}; raw_c_list = {};
    lin_n_list = {}; lin_c_list = {};

    for m = 1:numel(sub_items)
        it = sub_items(m);
        gt_file = it.clean_path;
        if isempty(gt_file), gt_file = it.gt_path; end

        rn = isp_raw.apply_blc(isp_io.read_crvd_tiff(it.noisy_path), it.bl, it.wl);
        rc = isp_raw.apply_blc(isp_io.read_crvd_tiff(gt_file),       it.bl, it.wl);

        raw_n_list{m} = rn;
        raw_c_list{m} = rc;

        if enable_raw_bnr
            [a_tmp, b_tmp] = utils.calibrate_ab_from_pairs({rn}, {rc}, false);
            w_zero = zeros(size(rn));
            rn_bnr = isp_raw.apply_raw_bnr(rn, w_zero, a_tmp, b_tmp, 1.0, 2.0);
        else
            rn_bnr = max(rn, 0);
        end
        rc_clean = max(rc, 0);

        rgb_c_dem = isp_color.apply_demosaic(rc_clean, it.bayer_pattern);
        [rgb_c_lin, wb_gain, ccm] = isp_color.apply_awb_ccm(rgb_c_dem, [], []);

        rgb_n_dem = isp_color.apply_demosaic(rn_bnr, it.bayer_pattern);
        [rgb_n_lin, ~, ~] = isp_color.apply_awb_ccm(rgb_n_dem, wb_gain, ccm);

        lin_n_list{m} = rgb_n_lin;
        lin_c_list{m} = rgb_c_lin;
    end

    % 1) 标定前端 Raw 域物理模型 (a_raw, b_raw)
    [a_raw, b_raw] = utils.calibrate_ab_from_pairs(raw_n_list, raw_c_list, false);
    a_raw_arr(idx_i) = a_raw;
    b_raw_arr(idx_i) = b_raw;

    % 2) 标定进入 Gamma/LTM 前的线性 RGB 等效模型 (a_eff, b_eff)
    [a_eff, b_eff] = utils.calibrate_ab_from_pairs(lin_n_list, lin_c_list, false);
    a_eff_arr(idx_i) = a_eff;
    b_eff_arr(idx_i) = b_eff;

    % 3) 方案2：测定各层实测噪声相对于全分辨率基准 sigma_0 的固定衰减比 [s0, s1, s2]
    cfg_tmp.iso = iso_val;
    cfg_tmp.a_iso = a_eff;
    cfg_tmp.b_iso = b_eff;
    cfg_tmp.max_3dnr_gain = 1.0;
    cfg_tmp.gf_k = [2.2, 2.8, 3.5];
    cfg_tmp.layer_noise_scale = [1.0, 1.0, 1.0];
    [lut_2d, Y_grid, g_grid] = noise_model.build_noise_lut_2d(x_lut, gamma_lut, cfg_tmp);

    r0_all = []; r1_all = []; r2_all = [];
    for m = 1:numel(lin_n_list)
        if enable_ltm
            [rgb_n_ltm, G_LTM] = isp_tone.apply_log_ltm(lin_n_list{m});
            [rgb_c_ltm, ~]     = isp_tone.apply_log_ltm(lin_c_list{m}, G_LTM);
        else
            rgb_n_ltm = lin_n_list{m};
            rgb_c_ltm = lin_c_list{m};
            G_LTM     = ones(size(rgb_n_ltm, 1), size(rgb_n_ltm, 2));
        end

        ycgco_n = ops.rgb2ycgco(isp_tone.apply_gamma(rgb_n_ltm, x_lut, gamma_lut));
        ycgco_c = ops.rgb2ycgco(isp_tone.apply_gamma(rgb_c_ltm, x_lut, gamma_lut));
        I_guide_c = ycgco_c(:,:,1);

        % 获取全图尺度的基础物理噪声估计 sigma_0
        w_zero = zeros(size(I_guide_c));
        sig_maps = noise_model.eval_pixel_sigma(I_guide_c, w_zero, G_LTM, lut_2d, Y_grid, g_grid, cfg_tmp);
        sig_0 = sig_maps.s0;
        sig_1 = sig_0(1:2:end, 1:2:end);
        sig_2 = sig_0(1:4:end, 1:4:end);

        pyr_n = pyramid.build_guided_pyramid(ycgco_n, sig_maps, cfg_tmp);
        pyr_c = pyramid.build_guided_pyramid(ycgco_c, sig_maps, cfg_tmp);

        d0_y = pyr_n.D0(:,:,1) - pyr_c.D0(:,:,1);
        d1_y = pyr_n.D1(:,:,1) - pyr_c.D1(:,:,1);
        d2_y = pyr_n.D2(:,:,1) - pyr_c.D2(:,:,1);

        m0 = (pyr_c.a0 < 0.08) & (sig_0 > 1e-5);
        m1 = (pyr_c.a1 < 0.08) & (sig_1 > 1e-5);
        m2 = (pyr_c.a2 < 0.08) & (sig_2 > 1e-5);

        if nnz(m0) > 200, r0_all = [r0_all; abs(d0_y(m0)) ./ sig_0(m0)]; end %#ok<AGROW>
        if nnz(m1) > 100, r1_all = [r1_all; abs(d1_y(m1)) ./ sig_1(m1)]; end %#ok<AGROW>
        if nnz(m2) >  50, r2_all = [r2_all; abs(d2_y(m2)) ./ sig_2(m2)]; end %#ok<AGROW>
    end

    % 方案2实测层间标定系数 (MAD 稳健估计高斯标准差)
    s0 = max(min(1.4826 * median(r0_all), 2.5), 0.2);
    s1 = max(min(1.4826 * median(r1_all), 2.5), 0.1);
    s2 = max(min(1.4826 * median(r2_all), 2.5), 0.05);
    layer_scale_mat(idx_i, :) = [s0, s1, s2];

    fprintf('  Raw域: a=%.4g, b=%.4g | 前级RGB等效: a_eff=%.4g, b_eff=%.4g\n', a_raw, b_raw, a_eff, b_eff);
    fprintf('  方案2实测层间衰减系数 [s0, s1, s2] = [%.3f, %.3f, %.3f]\n', s0, s1, s2);
end

out_dir = fullfile(jdef_dir, 'calibrated_profiles');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
cal_path = fullfile(out_dir, [sensor_name '.mat']);

cal_db.sensor_name       = sensor_name;
cal_db.iso_list          = iso_list;
cal_db.a_raw             = a_raw_arr;
cal_db.b_raw             = b_raw_arr;
cal_db.a_eff             = a_eff_arr;
cal_db.b_eff             = b_eff_arr;
cal_db.layer_noise_scale = layer_scale_mat;
cal_db.enable_raw_bnr    = enable_raw_bnr;
cal_db.enable_ltm        = enable_ltm;
cal_db.timestamp         = datestr(now, 'yyyy-mm-dd HH:MM:SS');

save(cal_path, 'cal_db');
fprintf('\n=== 标定完成！已保存到: %s ===\n', cal_path);