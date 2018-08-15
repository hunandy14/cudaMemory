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
//================================================================
int main(int argc, char const *argv[]) {
	//cuData_tester();
	return 0;
}
//================================================================
