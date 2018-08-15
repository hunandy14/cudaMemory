/*****************************************************************
Name : 
Date : 2018/01/08
By   : CharlotteHonG
Final: 2018/01/08
*****************************************************************/
#pragma once
#include <utility>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "cuImgData.cuh"

// ½u©Ê´¡¸É
void WarpScale_rgb(const cuImgData & uSrc, cuImgData & uDst, double ratio);
void WarpScale_rgb(const basic_ImgData &src, basic_ImgData &dst, double ratio);
void imgCopy(const cuImgData & uSrc, cuImgData & uDst);

void add(int* c);

