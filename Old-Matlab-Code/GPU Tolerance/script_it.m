load('munc13_8_frames_1_1000_it_21_t_neuro.mat');
[N, Nc, O, Oc, Sx, Sxc, Sy, Syc, X, Xc, Y, Yc, llv, Fn, lp] = gpu_tol(N, N_crlb, off_all, off_crlb, sigx_all, sigx_crlb, sigy_all, sigy_crlb, xf_all, xf_crlb, yf_all, yf_crlb, llv, framenum_all, lp, 21, 100, 2, 20000, 0, 15, 0, 4, 0, 0.4,0, 0.4, 0.5, 10, 0, 3, 0.4, 0.4, 0.4, -10000, 0);