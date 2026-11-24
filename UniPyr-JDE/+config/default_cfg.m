function cfg = default_cfg(iso, sensor_name)
% DEFAULT_CFG  UniPyr-JDE 通用算法参数配置
    if nargin < 1 || isempty(iso), iso = 1600; end
    if nargin < 2 || isempty(sensor_name), sensor_name = 'default_cmos'; end

    cfg.iso = iso;
    cfg.sensor_name = sensor_name;
    [cfg.a_iso, cfg.b_iso, layer_scale_iso] = config.sensor_profile_lut(iso, sensor_name);

    cfg.max_3dnr_gain     = 4.0;
    cfg.gf_k              = 1.*[15.0, 40.0, 90.0]; % 平滑尺度因子（放行纹理进 D，强边留在 S）
    cfg.gf_k_detect       = 4.0;                % 通用 2σ 信噪比检测基准 (var = 4*sigma^2 时 a=0.5)
    cfg.layer_noise_scale = layer_scale_iso;

    cfg.alpha_y           = [1.5, 1.7, 1.9];    % 配合 flat_boost=1.8 覆盖平坦区 2.4~3.0σ 噪声
    cfg.alpha_c           = [4.5, 5.1, 6.0];    % 补偿色度相对亮度的 2~3 倍放大率
    cfg.coring_damp_y     = 0.90;
    cfg.coring_damp_c     = 0.98;

    cfg.base_gain_l       = [3.0,2.5,2.0];%[3.8, 2.5, 2.25];
    cfg.iso_ref           = 100;
    cfg.iso_enh_decay     = 0.15;               % 每提升 1 档 EV (ISO翻倍) 的增强衰减系数
    cfg.usm_l0_strength   = 0.0;
    cfg.usm_max_overshoot = 0.05;
end