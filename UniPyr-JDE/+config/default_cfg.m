function cfg = default_cfg(iso, sensor_name)
% DEFAULT_CFG  UniPyr-JDE 参数配置（自动加载对应 ISO 的全流标定结果与逐层比例）
    if nargin < 1 || isempty(iso), iso = 1600; end
    if nargin < 2 || isempty(sensor_name), sensor_name = 'default_cmos'; end

    cfg.iso = iso;
    cfg.sensor_name = sensor_name;
    [cfg.a_iso, cfg.b_iso, layer_scale_iso] = config.sensor_profile_lut(iso, sensor_name);

    cfg.max_3dnr_gain     = 4.0;
%     cfg.gf_k              = [2.2, 2.8, 3.5];  % eps一般为2-3倍标定噪声方差
    cfg.layer_noise_scale = layer_scale_iso;  % 每层专属标定系数 [s0, s1, s2]
% 
%     cfg.alpha_y           = [1.3, 1.5, 1.6];
%     cfg.alpha_c           = [1.6, 2.6, 3.2];
%     cfg.coring_damp_y     = 0.85;
%     cfg.coring_damp_c     = 0.98;
    
    cfg.gf_k          = [8.0, 12.0, 16.0];  % 补偿 s_l^2，让平坦区 eps 真正达到输入方差的 2.5~4 倍
    cfg.alpha_y       = [2.2, 2.5, 2.8];    % 有效压制 1σ~2σ 亮噪
    cfg.alpha_c       = [3.5, 5.0, 6.5];    % 重点压制经过 AWB/CCM 放大后的高幅值彩噪
    cfg.coring_damp_y = 0.92;
    cfg.coring_damp_c = 0.98;

    % 补齐 ISO 6400 等中低档位拟合为 0 的暗部读出底噪
%     if cfg.b_iso < 1e-7
%         cfg.b_iso = 4.836e-5 * (iso / 25600)^2;
%     end

    cfg.base_gain_l       = [1,1,1];%[1.55, 1.35, 1.18];
    cfg.iso_ref           = 100;
    cfg.usm_l0_strength   = 0;%0.25;
    cfg.usm_max_overshoot = 0.05;
end