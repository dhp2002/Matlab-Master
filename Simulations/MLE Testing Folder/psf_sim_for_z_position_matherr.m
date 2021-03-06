%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PSF sim for z position
% AJN 3/30/15
%
% This script will generate a stack of gaussian point spread functions with
% the variables B, ntrue, x0true, y0true, z0true
% The outputs of this script are xf, yf, zf, a0, off0 the 3D coords, number of photons and offset (background) respectively
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all
clc
load('z_cal.mat');
%% Initialization
global xpix ypix wbox
rbox = 4;
[xpix, ypix] = meshgrid(-rbox:rbox,-rbox:rbox);
% xpix = gpuArray(xpix);
% ypix = gpuArray(ypix);
wbox = 2*rbox+1;
i1 = xpix.*0;
sxo = xsig;
syo = ysig;
axo = Ax;
bxo = Bx;
ayo = Ay;
byo = By;
gxo = - gx/1000;
gyo = gy/1000;
dxo = dx/1000;
dyo = dy/1000;
% gxo = -(gx*0.5+gy*0.5)/1000;
% gyo = (gx*0.5+gy*0.5)/1000;
% dxo = (dx*0.5 + dy*0.5)/1000;
% dyo = (dx*0.5 + dy*0.5)/1000;
% variables of image
B = 3;
ntrue = 200;
x0true = 2*(rand-0.5);
y0true = 2*(rand - 0.5);
% x0true = 0;
% y0true = 0;
z(1) = 0;
z(2) = 0;
frames = 10000;

z0true = z(round(rand)+1)/1000;

% sigx = sxo*(1 + ((z0true - gxo)/dxo).^2 + axo*((z0true - gxo)/dxo).^3 + bxo*((z0true - gxo)/dxo).^4).^0.5;
% sigy = syo*(1 + ((z0true - gyo)/dyo).^2 + ayo*((z0true - gyo)/dyo).^3 + byo*((z0true - gyo)/dyo).^4).^0.5;
sigx = sxo*(1 + ((z0true - gxo)/dxo).^2 + axo*((z0true - gxo)/dxo^(2/3)).^3 + bxo*((z0true - gxo)/dxo^(2/4)).^4).^0.5;
sigy = syo*(1 + ((z0true - gyo)/dyo).^2 + ayo*((z0true - gyo)/dyo^(2/3)).^3 + byo*((z0true - gyo)/dyo^(2/4)).^4).^0.5;
% r0t_pix = 2*sigma; % 1/e^2 radius
sigma2 = (1.9773);
r0t_um = 0.61*0.581/(1.4);        % Rayleigh radius in um
pix2pho = 1;
q = r0t_um / (sigma2);
wbox_um = q*wbox;



i1 = xpix.*0;
% Create a gaussian
% i1 = ntrue.*(2*pi*sigma^2)^-1.*exp(-((xpix-x0true).^2 +(ypix-y0true).^2)./(2*sigma.^2))+B;
            i1x = 1/2.*(erf((xpix - x0true + 1/2)./(2*sigx^2)^0.5)-erf((xpix - x0true - 1/2)./(2*sigx^2)^0.5)); % error function of x integration over psf for each pixel
            i1y = 1/2.*(erf((ypix - y0true + 1/2)./(2*sigy^2)^0.5)-erf((ypix - y0true - 1/2)./(2*sigy^2)^0.5)); % error function of y integration over psf for each pixel
   i1 = ntrue * i1x.*i1y+B;                 

%% Create Frames with noise
for i = 1:frames
%     waitbar(i/frames,w2, 'Creating points');
    i2(:,:,i) = double(imnoise(uint16(i1), 'poisson'))+.00001;
%     i2(:,:,i) = i1;
end
% imagesc(i2);
% colormap(gray);
% gpui2 = gpuArray(i2);

% close (w2)
w1 = waitbar(0,'Fitting, be patient');

%% Find molecules and fit them
for l = 1:frames
    waitbar(l/frames,w1 , 'Fitting be patient')
% i3 = gpui2(:,:,l);
i3 = i2(:,:,l);
% i3 = i1;
[highrow, highcol] = find(i3 == max(i3(:)),1);
highpix = max(i3(:));
k=0;
zlin = i3(:);
xfake = zlin.*0;
clear xguess yguess peakguess r0_allguess offguess beta0 Ex Ey u dudx dudy dudi dudb d2udx2 d2udy2 d2udi2 d2udb2 lowx lowy hix hiy
xguess = xpix(highrow,highcol);
yguess = ypix(highrow,highcol);


lowx = round(xguess-2*sigma2+rbox+1);
hix = round(xguess+2*sigma2+rbox+1);
lowy = round(yguess-2*sigma2+rbox+1);
hiy = round(xguess+2*sigma2+rbox+1);


if round(xguess-2*sigma2+rbox+1) <=0
    lowx = 1;
end
if round(xguess+2*sigma2+rbox+1) >= max(max(xpix))
    hix = max(max(xpix));
end
if round(yguess-2*sigma2+rbox+1) <=0
    lowy = 1;
    end
if round(xguess+2*sigma2+rbox+1) >= max(max(ypix))
    hiy = max(max(ypix));
end
N = max(max(i3))/2*pi*(2*sigma2/2)^2;
offguess = min(i3(:));

% beta0 = [ xguess, yguess, peakguess, sigma2/2, sigma2/2, offguess];
% 
% [beta,R,J,CovB,MSE] = nlinfit(xfake,zlin,@gaussguess, beta0);
% elapsed_nlon = toc;
%% MLE approximation
% sigma = sx;
xf = xguess;
yf = yguess;
zf = 0;
offs = offguess;
fittime(l) = 1;
% u = gpuArray(zeros(wbox,wbox,frames));
% while fittime(l) < 100
flag = 0;
for k = 1:20

%Define psf and error function for each pixel
    if abs(zf) > 1 || flag == 1
        zf = 0;
        flag = 1;
    end
    sx = sxo*(1 + ((zf - gxo)/dxo).^2 + axo*((zf - gxo)/dxo^(2/3)).^3 + bxo*((zf - gxo)/dxo^(2/4)).^4).^0.5;
    sy = syo*(1 + ((zf - gyo)/dyo).^2 + ayo*((zf - gyo)/dyo^(2/3)).^3 + byo*((zf - gyo)/dyo^(2/4)).^4).^0.5;

    Ex = 1/2.*(erf((xpix - xf + 1/2)./(2*sx^2)^0.5)-erf((xpix - xf - 1/2)./(2*sx^2)^0.5)); % error function of x integration over psf for each pixel
    Ey = 1/2.*(erf((ypix - yf + 1/2)./(2*sy^2)^0.5)-erf((ypix - yf - 1/2)./(2*sy^2)^0.5)); % error function of y integration over psf for each pixel

    u(:,:,k) = N.*Ex.*Ey + offs; % The underlying image is being created identical to 

    % partial derivatives of variables of interest
    dudx = N*(2*pi*sx^2)^-0.5.*(exp(-(xpix -xf - 1/2).^2.*(2*sx^2)^-1)-exp(-(xpix -xf + 1/2).^2.*(2*sx^2)^-1)).*Ey;
    dudy = N*(2*pi*sy^2)^-0.5.*(exp(-(ypix -yf - 1/2).^2.*(2*sy^2)^-1)-exp(-(ypix -yf + 1/2).^2.*(2*sy^2)^-1)).*Ex;
    dudsx = N*(2*pi)^(-1/2)*sx^(-2).*((xpix - xf - 1/2).*exp(-(xpix -xf - 1/2).^2.*(2*sx^2)^-1) - (xpix - xf + 1/2) .*exp(-(xpix -xf + 1/2).^2.*(2*sx^2)^-1)).*Ey; % pd sigx
    dudsy = N*(2*pi)^(-1/2)*sy^(-2).*((ypix - yf - 1/2).*exp(-(ypix -yf - 1/2).^2.*(2*sy^2)^-1) - (ypix - yf + 1/2) .*exp(-(ypix -yf + 1/2).^2.*(2*sy^2)^-1)).*Ex; % pd sigy
    dsxdz = sxo*(2 * (zf - gxo) / (dxo*dxo) + axo * 3 * ((zf-gxo)^2/dxo^2) + bxo*4*((zf-gxo)^3/dxo^2))/ (2*(1 + ((zf - gxo)/dxo).^2 + axo*((zf - gxo)/dxo^(2/3)).^3 + bxo*((zf - gxo)/dxo^(2/4)).^4).^0.5);
    dsydz = syo*(2 * (zf - gyo) / (dyo*dyo) + ayo * 3 * ((zf-gyo)^2/dyo^2) + byo*4*((zf-gyo)^3/dyo^2))/ (2*(1 + ((zf - gyo)/dyo).^2 + ayo*((zf - gyo)/dyo^(2/3)).^3 + byo*((zf - gyo)/dyo^(2/4)).^4).^0.5);
    dudz = dudsx*dsxdz + dudsy*dsydz;
    % It was noticed in the current GPU codes that there was a parentheses
    % error putting a major denominator term in the numerator
    
    dudi = Ex.*Ey;
    dudb = 1;
    
    
    % Second partial derivatives of variables of interest
    d2udx2 = N*(2*pi)^-0.5*sx^-3*((xpix - xf - 1/2).*exp(-(xpix -xf - 1/2).^2.*(2*sx^2)^-1) - (xpix - xf + 1/2) .*exp(-(xpix -xf + 1/2).^2.*(2*sx^2)^-1)).*Ey;
    d2udy2 = N*(2*pi)^-0.5*sy^-3*((ypix - yf - 1/2).*exp(-(ypix -yf - 1/2).^2.*(2*sy^2)^-1) - (ypix - yf + 1/2) .*exp(-(ypix -yf + 1/2).^2.*(2*sy^2)^-1)).*Ex;
        d2udsx2 = N.*Ey.*(2*pi)^-0.5.*((sx^-5.* ((xpix - xf - 1/2).^3.*exp(-(xpix -xf - 1/2).^2.*(2*sx^2)^-1) - (xpix - xf + 1/2).^3.*exp(-(xpix -xf + 1/2).^2.*(2*sx^2)^-1))) ...
            - 2.*sx.^-3.*((xpix - xf - 1/2).*   exp(-(xpix -xf - 1/2).^2.*(2*sx^2)^-1) - (xpix - xf + 1/2) .*  exp(-(xpix -xf + 1/2).^2.*(2*sx^2)^-1)));
        % second partial for sigmay
        d2udsy2 = N.*Ex.*(2*pi)^-0.5.*((sy^-5.* ((ypix - yf - 1/2).^3.*exp(-(ypix -yf - 1/2).^2.*(2*sy^2)^-1) - (ypix - yf + 1/2).^3.*exp(-(ypix -yf + 1/2).^2.*(2*sy^2)^-1))) ...
            - 2.*sy.^-3.*((ypix - yf - 1/2).*   exp(-(ypix -yf - 1/2).^2.*(2*sy^2)^-1) - (ypix - yf + 1/2)   .*exp(-(ypix -yf + 1/2).^2.*(2*sy^2)^-1)));
    d2sxdz2 = sxo*(2/(dxo)^2 + axo*6*(zf-gxo)/(dxo)^3 + bxo*12*(zf-gxo)^2/(dxo)^4)/ (2*(1 + ((zf - gxo)/dxo).^2 + axo*((zf - gxo)/dxo).^3 + bxo*((zf - gxo)/dxo).^4).^0.5)...
        - sxo*(2 * (zf - gxo) / (dxo*dxo) + axo * 3 * ((zf-gxo)^2/dxo^2) + bxo*4*((zf-gxo)^3/dxo^2))^2/ (4*(1 + ((zf - gxo)/dxo).^2 + axo*((zf - gxo)/dxo^(2/3)).^3 + bxo*((zf - gxo)/dxo^(2/4)).^4).^1.5);
    d2sydz2 = syo*(2/(dyo)^2 + ayo*6*(zf-gyo)/(dyo)^3 + byo*12*(zf-gyo)^2/(dyo)^2)/ (2*(1 + ((zf - gyo)/dyo).^2 + ayo*((zf - gyo)/dyo).^3 + byo*((zf - gyo)/dyo).^4).^0.5)...
        - syo*(2 * (zf - gyo) / (dyo*dyo) + ayo * 3 * ((zf-gyo)^2/dyo^2) + byo*4*((zf-gyo)^3/dyo^2))^2/ (4*(1 + ((zf - gyo)/dyo).^2 + ayo*((zf - gyo)/dyo^(2/3)).^3 + byo*((zf - gyo)/dyo^(2/4)).^4).^1.5);
    d2udz2 = d2udsx2*dsxdz^2 + dudsx*d2sxdz2 + d2udsy2*dsydz^2 + dsydz*d2sydz2;
    d2udi2 = 0;
    d2udb2 = 0;
    
    xlap(k,l) = xf;
    ylap(k,l) = yf;
    zlap(k,l) = zf;
    nlap(k,l) = N;
    bglap(k,l) = offs;
    % update variables
    xf = xf - sum(sum(dudx.*((i3./u(:,:,k))-1)))/(sum(sum(d2udx2.*((i3./u(:,:,k))-1) - dudx.^2.*i3./(u(:,:,k).^2))));
    yf = yf - sum(sum(dudy.*((i3./u(:,:,k))-1)))/(sum(sum(d2udy2.*((i3./u(:,:,k))-1) - dudy.^2.*i3./(u(:,:,k).^2))));
    zf = zf - sum(sum(dudz.*((i3./u(:,:,k))-1)))/(sum(sum(d2udz2.*((i3./u(:,:,k))-1) - dudz.^2.*i3./(u(:,:,k).^2))));
    N = N - sum(sum(dudi.*((i3./u(:,:,k))-1)))/(sum(sum(d2udi2.*((i3./u(:,:,k))-1) - dudi.^2.*i3./(u(:,:,k).^2))));
    offs = offs - sum(sum(dudb.*((i3./u(:,:,k))-1)))/(sum(sum(d2udb2.*((i3./u(:,:,k))-1) - dudb.^2.*i3./(u(:,:,k).^2))));
    


end   
    xlap(k+1,l) = xf;
    ylap(k+1,l) = yf;
    zlap(k+1,l) = zf;
    nlap(k+1,l) = N;
    bglap(k+1,l) = offs;
    flagy(l) = flag;
    p(l) = sum(sum(i3.*real(log(u(:,:,end)))-u(:,:,end)-i3.*real(log(i3))+i3));

% end

xfa(l) = xf;
yfa(l) = yf;
a0(l) = N;
r0(l) = (sx*sy)^0.5;
zfa(l) = zf;
% sigy(l) = sy;
off0(l) = offs;
end

close (w1)
% xf = xf;
% yf = yf;
% a0 = N;
% r0 = sx;
% off0 = sy;
% rf = (xf.^2+yf.^2).^0.5;
% hist(rf*q*1000,1:2:80);
% drawnow
% % end
% imagesc(u*1000);
% subplot(1,2,1);imagesc(i2);
% subplot(1,2,2);imagesc(u(:,:,l)*1000000);
% axis image
% colormap('gray');
% plot(1:60,xf.*q)
numel(find(fittime==101))
imagesc(i2(:,:,1));
axis image
colormap('gray')
hold on
plot(xfa+rbox+1, yfa+rbox+1, '.b');
plot(x0true+rbox+1,y0true+rbox+1,'.r')
title('PSF with blue localizations and red source')
figure
plot(1:k+1,zlap);
title('Convergence of fitting parameter')
xlabel('Iteration')
ylabel('Value')
figure
h = histogram(zfa(:,logical(1-flagy)));
vals = h.Values;
hold on
plot([z0true, z0true],[0, max(vals)],'r');
hold off