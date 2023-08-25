function getRotationPrecomputeL(precompute_L, rotationMatrix){
	let rgbMat3 = getMat3ValueFromRGB(precompute_L);

	let M3 = computeSquareMatrix_3by3(rotationMatrix);
	let M5 = computeSquareMatrix_5by5(rotationMatrix);

	rotateChannel(M3, M5, rgbMat3[0]);
	rotateChannel(M3, M5, rgbMat3[1]);
	rotateChannel(M3, M5, rgbMat3[2]);

	return rgbMat3;
}

function rotateChannel(M3, M5, dataArray) {
	let C3 = math.matrix(Array.from(dataArray.slice(1, 4)));
	let C5 = math.matrix(Array.from(dataArray.slice(4, 9)));
	let N3 = math.multiply(M3, C3);
	let N5 = math.multiply(M5, C5);
	let N8 = math.concat(N3, N5);

	for (let i = 0; i != 8; i++) {
		dataArray[i + 1] = N8.get([i]);
	}
}

function computeSquareMatrix_3by3(rotationMatrix){ // 计算方阵SA(-1) 3*3 
	
	// 1、pick ni - {ni}
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [0, 1, 0, 0];

	// 2、{P(ni)} - A  A_inverse
	let p1 = SHEval(n1[0], n1[1], n1[2], 3);
	let p2 = SHEval(n2[0], n2[1], n2[2], 3);
	let p3 = SHEval(n3[0], n3[1], n3[2], 3);
	let A = math.matrix([p1.slice(1, 4), p2.slice(1, 4), p3.slice(1, 4)]);

	// 3、用 R 旋转 ni - {R(ni)}
	let R = mat4Matrix2mathMatrix(rotationMatrix);
	let r1 = math.multiply(R, n1);
	let r2 = math.multiply(R, n2);
	let r3 = math.multiply(R, n3);

	// 4、R(ni) SH投影 - S
	let s1 = SHEval(r1.get([0]), r1.get([1]), r1.get([2]), 3);
	let s2 = SHEval(r2.get([0]), r2.get([1]), r2.get([2]), 3);
	let s3 = SHEval(r3.get([0]), r3.get([1]), r3.get([2]), 3);

	let S = math.matrix([s1.slice(1, 4), s2.slice(1, 4), s3.slice(1, 4)]);

	// 5、S*A_inverse
	let A_inv = math.inv(A);
	let M = math.multiply(S, A_inv);
	return M;
}

function computeSquareMatrix_5by5(rotationMatrix){ // 计算方阵SA(-1) 5*5
	
	// 1、pick ni - {ni}
	let k = 1 / math.sqrt(2);
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [k, k, 0, 0]; 
	let n4 = [k, 0, k, 0]; let n5 = [0, k, k, 0];

	// 2、{P(ni)} - A  A_inverse
	let p1 = SHEval(n1[0], n1[1], n1[2], 3);
	let p2 = SHEval(n2[0], n2[1], n2[2], 3);
	let p3 = SHEval(n3[0], n3[1], n3[2], 3);
	let p4 = SHEval(n4[0], n4[1], n4[2], 3);
	let p5 = SHEval(n5[0], n5[1], n5[2], 3);
	let A = math.matrix([p1.slice(4, 9), p2.slice(4, 9), p3.slice(4, 9), p4.slice(4, 9), p5.slice(4, 9)]);

	// 3、用 R 旋转 ni - {R(ni)}
	let R = mat4Matrix2mathMatrix(rotationMatrix);
	let r1 = math.multiply(R, n1);
	let r2 = math.multiply(R, n2);
	let r3 = math.multiply(R, n3);
	let r4 = math.multiply(R, n4);
	let r5 = math.multiply(R, n5);

	// 4、R(ni) SH投影 - S
	let s1 = SHEval(r1.get([0]), r1.get([1]), r1.get([2]), 3);
	let s2 = SHEval(r2.get([0]), r2.get([1]), r2.get([2]), 3);
	let s3 = SHEval(r3.get([0]), r3.get([1]), r3.get([2]), 3);
	let s4 = SHEval(r4.get([0]), r4.get([1]), r4.get([2]), 3);
	let s5 = SHEval(r5.get([0]), r5.get([1]), r5.get([2]), 3);

	let S = math.matrix([s1.slice(4, 9), s2.slice(4, 9), s3.slice(4, 9), s4.slice(4, 9), s5.slice(4, 9)]);

	// 5、S*A_inverse
	let A_inv = math.inv(A);
	let M = math.multiply(S, A_inv);
	return M;
}

function mat4Matrix2mathMatrix(rotationMatrix){

	let mathMatrix = [];
	for(let i = 0; i < 4; i++){
		let r = [];
		for(let j = 0; j < 4; j++){
			r.push(rotationMatrix[i*4+j]);
		}
		mathMatrix.push(r);
	}
	return math.matrix(mathMatrix)

}

function getMat3ValueFromRGB(precomputeL){

    let colorMat3 = [];
    for(var i = 0; i<3; i++){
        colorMat3[i] = mat3.fromValues( precomputeL[0][i], precomputeL[1][i], precomputeL[2][i],
										precomputeL[3][i], precomputeL[4][i], precomputeL[5][i],
										precomputeL[6][i], precomputeL[7][i], precomputeL[8][i] ); 
	}
    return colorMat3;
}