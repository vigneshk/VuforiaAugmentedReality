/*
created with obj2opengl.pl

source file    : ./quad.obj
vertices       : 4
faces          : 1
normals        : 0
texture coords : 0


// include generated arrays
#import "./quad.h"

// set input data to arrays
glVertexPointer(3, GL_FLOAT, 0, quadVerts);

// draw data
glDrawArrays(GL_TRIANGLES, 0, quadNumVerts);
*/

unsigned int quadNumVerts = 3;

float quadVerts [] = {
  // f   1 2 3 
  -0.5, -0.5, 0,
  0.5, -0.5, 0,
  0.5, 0.5, 0,
};

