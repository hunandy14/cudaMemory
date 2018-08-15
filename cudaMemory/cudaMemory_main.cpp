/*****************************************************************
Name :
Date : 2018/08/15
By   : CharlotteHonG
Final: 2018/08/15
*****************************************************************/
#include <iostream>
#include <vector>
#include <string>
using namespace std;

#include "cuMem.cuh"
#include "cuImgData.cuh"
#include "cubilinear/cubilinear.cuh"

void cuData_print(const cuMem<int>& cu) {
	vector<int> V1(cu.size());
	cu.memcpyOut(V1.data(), cu.size());
	cout << "  ";
	for (size_t i = 0; i < V1.size(); i++){
		cout << V1[i] << ", ";
	} cout << endl;
}
void cuData_tester() {
	// 資料
	vector<int> V1{ 1, 2, 3 };
	vector<int> V2{ 3, 2, 1 };


	cout << "初始化" << endl;
	cuMem<int> uV1(V1.size());
	cuData_print(uV1);
	uV1.memcpyIn(V1.data(), V1.size());
	cuData_print(uV1);

	cout << "建構初始化" << endl;
	cuMem<int> uV2(V2.data(), V2.size());
	cuData_print(uV2);

	cout << "記憶體複製" << endl;
	cuMem<int> uV3=uV2;
	cuData_print(uV3);

	cout << "記憶體移動" << endl;
	cuMem<int> uV4=std::move(uV3);
	cuData_print(uV4);
	cout << "uV3 add = " << uV3 << endl;
	cout << "uV4 add = " << uV4 << endl;
}
void cuImgData_tester() {
	ImgData img("cat.bmp"), out;
	WarpScale_rgb(img, out, 0.5);
	out.bmp("out.bmp");

	ImgData img2("out.bmp"), out2;
	cuImgData uimg(img), uout2(img);
	uout2.resize(img);
	//WarpScale_rgb(uimg, uout2, 0.5);
	imgCopy(uimg, uout2);

	uimg.out(out2);
	out2.bmp("out2.bmp");
}

void cuImgData_tester2() {
	// 資料
	vector<int> V1{ 1, 2, 3 };
	cuMem<int> uV1(V1.data(), V1.size());
	uV1.memcpyIn(V1.data(), V1.size());
	cuData_print(uV1);

	add(uV1);
	cuData_print(uV1);

}
//================================================================
int main(int argc, char const *argv[]) {
	//cuData_tester();
	//cuImgData_tester();
	cuImgData_tester2();
	return 0;
}
//================================================================
