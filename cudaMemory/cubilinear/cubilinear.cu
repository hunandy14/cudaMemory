/***************************************************************************************
Name :
Date : 2018/01/08
By   : CharlotteHonG
Final: 2018/01/08
***************************************************************************************/
#include <utility>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>
using namespace std;

#include "cubilinear.hpp"
#define BLOCK_DIM 16.0
#define BLOCK_DIM_X 32.0
#define BLOCK_DIM_Y 8.0

using uch = unsigned char;

//======================================================================================
// 快速線性插值_核心
__device__ __host__ static inline
void fast_Bilinear(const uch* src, int w, int h,
	uch* p, double y, double x)
{
	int srcW = w;
	int srcH = h;

	// 起點
	int _x = (int)x;
	int _y = (int)y;
	// 左邊比值
	double l_x = x - (double)_x;
	double r_x = 1.f - l_x;
	double t_y = y - (double)_y;
	double b_y = 1.f - t_y;

	// 計算RGB
	double R , G, B;
	int x2 = (_x+1) > srcW -1? srcW -1: _x+1;
	int y2 = (_y+1) > srcH-1? srcH-1: _y+1;

	R  = (double)src[(_y * srcW + _x) *3 + 0] * (r_x * b_y);
	G  = (double)src[(_y * srcW + _x) *3 + 1] * (r_x * b_y);
	B  = (double)src[(_y * srcW + _x) *3 + 2] * (r_x * b_y);
	R += (double)src[(_y * srcW + x2) *3 + 0] * (l_x * b_y);
	G += (double)src[(_y * srcW + x2) *3 + 1] * (l_x * b_y);
	B += (double)src[(_y * srcW + x2) *3 + 2] * (l_x * b_y);
	R += (double)src[(y2 * srcW + _x) *3 + 0] * (r_x * t_y);
	G += (double)src[(y2 * srcW + _x) *3 + 1] * (r_x * t_y);
	B += (double)src[(y2 * srcW + _x) *3 + 2] * (r_x * t_y);
	R += (double)src[(y2 * srcW + x2) *3 + 0] * (l_x * t_y);
	G += (double)src[(y2 * srcW + x2) *3 + 1] * (l_x * t_y);
	B += (double)src[(y2 * srcW + x2) *3 + 2] * (l_x * t_y);

	p[0] = (unsigned char) R;
	p[1] = (unsigned char) G;
	p[2] = (unsigned char) B;
}
// 快速線性插值
__global__ 
void cuWarpScale_kernel(const uch* src, uch* dst, 
	int w, int h, double ratio)
{
	int srcW=w;
	int srcH=h;

	int dstW = (int)((srcW * ratio) +0.5);
	int dstH = (int)((srcH * ratio) +0.5);

	// 縮小的倍率
	double r1W = ((double)srcW )/(dstW);
	double r1H = ((double)srcH)/(dstH);
	// 放大的倍率
	double r2W = (srcW -1.0)/(dstW -1.0);
	double r2H = (srcH-1.0)/(dstH-1.0);
	// 縮小時候的誤差
	double deviW = ((srcW-1.0)  - (dstW -1.0)*(r1W)) /dstW;
	double deviH = ((srcH-1.0) - (dstH-1.0)*(r1H)) /dstH;

	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if(j < dstH && i < dstW) { // 會多跑一點點要擋掉
			double srcY, srcX;
			if (ratio < 1.0) {
				srcX = i*(r1W+deviW);
				srcY = j*(r1H+deviH);
			} else if (ratio >= 1.0) {
				srcX = i*r2W;
				srcY = j*r2H;
			}
			// 獲取插補值
			unsigned char* p = &dst[(j*dstW+ i) *3];
			fast_Bilinear(src, w, h, p, srcY, srcX);
		
	}
}
// GPU 線性插值
__host__
void WarpScale_rgb(const cuImgData & uSrc, cuImgData & uDst, double ratio) {
	// 設置大小
	int dstW = (int)((uSrc.width  * ratio) +0.5);
	int dstH = (int)((uSrc.height * ratio) +0.5);
	// 不相同則resize
	if(uDst.width != dstW || uDst.height != dstH || uDst.bits != uSrc.bits) 
		uDst.resize(dstW, dstH, uSrc.bits);
	// 設置執行緒
	dim3 block(BLOCK_DIM_X, BLOCK_DIM_Y);
	dim3 grid(ceil(dstW / BLOCK_DIM_X), ceil(dstH / BLOCK_DIM_Y));
	// 執行 kernel
	cuWarpScale_kernel <<< grid, block >>> (uSrc, uDst, uSrc.width, uSrc.height, ratio);
}
// 測試 cuWarpScale_kernel
__host__
void cuWarpScale_kernel_test(const basic_ImgData & src, basic_ImgData & dst, double ratio){
	Timer t;
	// 初始化空間
	//t.start();
	// 初始化 dst
	dst.width  = (int)((src.width  * ratio) +0.5);
	dst.height = (int)((src.height * ratio) +0.5);
	dst.bits   = src.bits;
	dst.raw_img.resize(dst.width * dst.height * dst.bits>>3);
	//t.print("  resize");

	// 要求GPU空間
	//t.start();
	cuMem<uch> gpuSrc(src.raw_img.size());
	//t.print("  cudamalloc gpuSrc");
	//t.start();
	cuMem<uch> gpuDst(dst.raw_img.size());
	//t.print("  cudamalloc gpuDst");

	// 複製資料
	// t.start();/
	gpuSrc.memcpyIn(src.raw_img.data(), src.raw_img.size());
	// t.print("  memcpyIn");

	// 設置執行緒
	dim3 block(BLOCK_DIM, BLOCK_DIM);
	dim3 grid(ceil(dst.width / BLOCK_DIM), ceil(dst.width / BLOCK_DIM));

	// 執行 kernel
	// t.start();
	cuWarpScale_kernel <<< grid, block >>> (gpuSrc, gpuDst, src.width, src.height, ratio);
	// t.print("  kernel");

	// 複製資料
	// t.start();
	gpuDst.memcpyOut(dst.raw_img.data(), dst.raw_img.size());
	// t.print("  memcpyOut");


	// t.start();
	gpuDst.~cuMem<uch>();
	// t.print("  dctor");
}
