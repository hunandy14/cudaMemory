﻿/*****************************************************************
Name : 
Date : 2018/01/09
By   : CharlotteHonG
Final: 2018/01/09
*****************************************************************/
#pragma once
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <utility>

// Cuda 記憶體自動管理程序
template <class T>
class cuMem {
public:
	cuMem() = default;
	// 初始化特定長度
	cuMem(size_t size){
		malloc(size);
	}
	cuMem(const T* dataIn ,size_t size): len(size){
		malloc(size);
		memcpyIn(dataIn, size);
	}
	virtual ~cuMem(){
		free();
	}
public: // rule of five
	cuMem(const cuMem& rhs) {
		//cout << "cuMem::ctor" << endl;
		malloc(rhs.len);
		cudaMemcpy(this->gpuData, rhs.gpuData, 
				rhs.len*sizeof(T), cudaMemcpyDeviceToDevice);
	}
	cuMem(cuMem&& rhs) noexcept:
		gpuData(std::exchange(rhs.gpuData, nullptr)), 
		len(std::exchange(rhs.len, 0))
	{
		//cout << "cuMem::cmove" << endl;
	}
	cuMem& operator=(const cuMem& rhs) {
		//cout << "cuMem::copy" << endl;
		if (this != &rhs) {
			resize(rhs.len);
			cudaMemcpy(this->gpuData, rhs.gpuData, 
				rhs.len*sizeof(T), cudaMemcpyDeviceToDevice);
		}
		return *this;
	}
	cuMem& operator=(cuMem&& rhs) noexcept {
		//cout << "cuMem::move" << endl;
		if(this != &rhs) {
			free();
			gpuData = std::exchange(rhs.gpuData, nullptr);
			len = std::exchange(rhs.len, 0);
		}
		return *this;
	}
public: // 記憶體函式轉發
	void malloc(size_t size) {
		//cout << "cuMem malloc" << endl;
		if(gpuData != nullptr) {throw runtime_error("malloc::gpudata is not empty.");}
		cudaMalloc((void**)&gpuData, size*sizeof(T));
		len = size;
	}
	void free() {
		if(gpuData != nullptr) {
			cudaFree(gpuData);
			gpuData = nullptr;
			len = 0;
		}
	}
	void memcpyIn(const T* dataIn ,size_t size) {
		if(size > len) {throw out_of_range("memcpyIn::input size > gpudata size.");}
		cudaMemcpy(gpuData, dataIn, size*sizeof(T), cudaMemcpyHostToDevice);
	}
	void memcpyOut(T* dst ,size_t size) const {
		if(size > len) {throw out_of_range("memcpyOut::ouput size > gpudata size.");}
		cudaMemcpy(dst, gpuData, size*sizeof(T), cudaMemcpyDeviceToHost);
	}
	void memset(int value, size_t size) {
		if(size>len) {throw out_of_range("memset::input size > gpudata size.");}
		cudaMemset(gpuData, value, size*sizeof(T));
	}
	void swap(cuMem& other) {
		std::swap(this->gpuData, other.gpuData);
		std::swap(this->len, other.len);
	}
public:
	void resize(size_t size) {
		if(size > len) {
			free();
			malloc(size);
		} len = size;
	}
	size_t size() const {
		return this->len;
	}
public:
	operator T*() {
		return gpuData;
	}
	operator const T*() const {
		return gpuData;
	}
public:
	T* gpuData = nullptr;
	size_t len = 0;
};

// 預啟動cuda核心
static cuMem<int> __CudaGPUCoreInit__(1);


// CudaArr 記憶體自動管理程序
/*
template <class T>
class CudaMemArr {
public:
	CudaMemArr(){}
	CudaMemArr(size_t dstW, size_t dstH):
		width(dstW), height(dstH)
	{
		malloc(dstW, dstH);
	}
	CudaMemArr(const T* dataIn ,size_t dstW, size_t dstH): 
		width(dstW), height(dstH)
	{
		malloc(dstW, dstH);
		memcpyIn(dataIn, dstW*dstH);
	}
	~CudaMemArr(){
		if(cuArray!=nullptr) {
			cudaFreeArray(cuArray);
			cuArray = nullptr;
			width = height = 0;
		}
	}
public:
	void malloc(size_t dstW, size_t dstH) {
		this->~CudaMemArr();
		cudaMallocArray(&cuArray, &chDesc, dstW, dstH);
	}
	void memcpyIn(const T* dataIn ,size_t size) {
		if(size > width*height) {throw out_of_range("memcpyIn input size > curr size.");}
		cudaMemcpyToArray(cuArray, 0, 0, dataIn, size*sizeof(T), cudaMemcpyHostToDevice);
	}
	size_t size() {
		return width*height;
	}
public:
	operator cudaArray*() {
		return cuArray;
	}
public:
	const cudaChannelFormatDesc chDesc = cudaCreateChannelDesc<T>();
private:
	size_t width = 0;
	size_t height = 0;
	cudaArray* cuArray = nullptr;
};
*/