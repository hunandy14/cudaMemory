﻿/***************************************************************************************
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

#include "cubilinear.cuh"
#define BLOCK_DIM 16.0
#define BLOCK_DIM_X 16.0
#define BLOCK_DIM_Y 16.0

using uch = unsigned char;

//======================================================================================
// 複製圖片
__global__ void addKernel(uch *c)
{
	int i = threadIdx.x;
	c[i] = 128;
}

__global__ void addKernel2(int *c)
{
	int i = threadIdx.x;
	c[i] = 128;
}
__host__ void add(int* c) {
	addKernel2<<<1, 3>>>(c);
}

__global__
void imgCopy_kernel(const uch* src, uch* dst, int w, int h)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if(j < h && i < w) { // 會多跑一點點要擋掉
		int srcIdx = (j*w +i) *3;
		int dstIdx = (j*w +i) *3;

		//dst[dstIdx+0] = src[srcIdx+0];
		//dst[dstIdx+1] = src[srcIdx+1];
		//dst[dstIdx+2] = src[srcIdx+2];


		dst[dstIdx+0] = 128;
		dst[dstIdx+1] = 128;
		dst[dstIdx+2] = 128;
	}					
}
// 複製圖片
__host__
void imgCopy(const cuImgData & uSrc, cuImgData & uDst) {
	// 設置大小
	int srcW = uSrc.width;
	int srcH = uSrc.height;

	uDst.resize(uSrc);

	//// 設置執行緒
	//dim3 block(BLOCK_DIM_X, BLOCK_DIM_Y);
	//dim3 grid(ceil(srcW / BLOCK_DIM_X)+1, ceil(srcH / BLOCK_DIM_Y)+1);

	//// 執行 kernel
	//imgCopy_kernel <<< grid, block >>> (uSrc, uDst, srcW, srcH);
	cout << "go = " << srcW*srcH << endl;
	addKernel<<<1, srcW*srcH>>>(uSrc.gpuData);
}
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
//==============================================
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
//==============================================
// CPU快速線性插值
__host__
void WarpScale_rgb(const basic_ImgData &src, basic_ImgData &dst, double ratio){
	// 防呆
	if (src.bits != 24) runtime_error("IMG is not 24bit.");
	// 初始化 dst
	dst.width  = (int)((src.width  * ratio) +0.5);
	dst.height = (int)((src.height * ratio) +0.5);
	dst.bits   = src.bits;
	dst.raw_img.resize(dst.width * dst.height * dst.bits>>3);

	// 縮小的倍率
	double r1W = ((double)src.width )/(dst.width );
	double r1H = ((double)src.height)/(dst.height);
	// 放大的倍率
	double r2W = (src.width -1.0)/(dst.width -1.0);
	double r2H = (src.height-1.0)/(dst.height-1.0);
	// 縮小時候的誤差
	double deviW = ((src.width-1.0)  - (dst.width -1.0)*(r1W)) /dst.width;
	double deviH = ((src.height-1.0) - (dst.height-1.0)*(r1H)) /dst.height;

	// 跑新圖座標
	//#pragma omp parallel for
	for (int j = 0; j < dst.height; ++j) {
		for (int i = 0; i < dst.width; ++i) {
			// 調整對齊
			double srcY, srcX;
			if (ratio < 1.0) {
				srcX = i*(r1W+deviW);
				srcY = j*(r1H+deviH);
			} else if (ratio >= 1.0) {
				srcX = i*r2W;
				srcY = j*r2H;
			}
			// 獲取插補值
			unsigned char* p = &dst.raw_img[(j*dst.width + i) *3];
			fast_Bilinear(src.raw_img.data(), src.width, src.height, p, srcY, srcX);
		}
	}
}