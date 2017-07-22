/*
Copyright (c) 2017 Alberto Otero de la Roza
<aoterodelaroza@gmail.com>, Robin Myhr <x@example.com>, Isaac
Visintainer <x@example.com>, Richard Greaves <x@example.com>, Ángel
Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
<victor@fluor.quimica.uniovi.es>.

critic2 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

critic2 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "GL/freeglut.h"

#include "imgui.h"
#include "imgui_impl_glut.h"

using namespace std;

// xxxx //

unsigned int screenWidth = 1280;
unsigned int screenHeight = 720;
bool show_test_window = true;
bool show_another_window = false;

void drawGUI()
{
    ImGui_ImplGLUT_NewFrame(screenWidth, screenHeight);

    // 1. Show a simple window
    // Tip: if we don't call ImGui::Begin()/ImGui::End() the widgets appears in a window automatically called "Debug"
    {
        static float f = 0.0f;
        ImGui::Text("Hello, world!");
        ImGui::SliderFloat("float", &f, 0.0f, 1.0f);
        if (ImGui::Button("Test Window")) show_test_window ^= 1;
        if (ImGui::Button("Another Window")) show_another_window ^= 1;
        ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
    }

    // 2. Show another simple window, this time using an explicit Begin/End pair
    if (show_another_window)
    {
        ImGui::SetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
        ImGui::Begin("Another Window", &show_another_window);
        ImGui::Text("Hello");
        ImGui::End();
    }

    // // 3. Show the ImGui test window. Most of the sample code is in ImGui::ShowTestWindow()
    // if (show_test_window)
    // {
    //     ImGui::SetNextWindowPos(ImVec2(650, 20), ImGuiSetCond_FirstUseEver);
    //     ImGui::ShowTestWindow(&show_test_window);
    // }

    ImGui::Render();
}

void drawScene()
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    // add code here to draw scene objects
    glColor3f(1.0, 0.0, 0.0);
    glBegin(GL_TRIANGLES);
    glVertex3f(-1.0, -1.0, 0.0);
    glVertex3f(1.0, -1.0, 0.0);
    glVertex3f(0.0, 1.0, 0.0);
    glEnd();

    // draw gui, seems unnecessary to push/pop matrix and attributes
    //glPushMatrix();
    //glPushAttrib(GL_ALL_ATTRIB_BITS);
    drawGUI();
    //glPopAttrib();
    //glPopMatrix();

    glutSwapBuffers();
    glutPostRedisplay();
}

bool keyboardEvent(unsigned char nChar, int nX, int nY)
{
    ImGuiIO& io = ImGui::GetIO();
    io.AddInputCharacter(nChar);

    if (nChar == 27) //Esc-key
        glutLeaveMainLoop();

    return true;
}

void KeyboardSpecial(int key, int x, int y)
{
    ImGuiIO& io = ImGui::GetIO();
    io.AddInputCharacter(key);
}

bool mouseEvent(int button, int state, int x, int y)
{
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2((float)x, (float)y);

    if (state == GLUT_DOWN && (button == GLUT_LEFT_BUTTON))
        io.MouseDown[0] = true;
    else
        io.MouseDown[0] = false;

    if (state == GLUT_DOWN && (button == GLUT_RIGHT_BUTTON))
        io.MouseDown[1] = true;
    else
        io.MouseDown[1] = false;

    return true;
}

void mouseWheel(int button, int dir, int x, int y)
{
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2((float)x, (float)y);
    if (dir > 0)
    {
        // Zoom in
        io.MouseWheel = 1.0;
    }
    else if (dir < 0)
    {
        // Zoom out
        io.MouseWheel = -1.0;
    }
}

void reshape(int w, int h)
{
    // update screen width and height for imgui new frames
    screenWidth = w;
    screenHeight = h;

    // Prevent a divide by zero, when window is too short
    // (you cant make a window of zero width).
    if (h == 0)
        h = 1;
    float ratio = 1.0* w / h;

    // Use the Projection Matrix
    glMatrixMode(GL_PROJECTION);

    // Reset Matrix
    glLoadIdentity();

    // Set the viewport to be the entire window
    glViewport(0, 0, w, h);

    // Set the correct perspective.
    gluPerspective(45, ratio, 1, 1000);

    // Get Back to the Modelview
    glMatrixMode(GL_MODELVIEW);
    glTranslatef(0.0, 0.0, -2.0);
}

void keyboardCallback(unsigned char nChar, int x, int y)
{
    if (keyboardEvent(nChar, x, y))
    {
        glutPostRedisplay();
    }
}

void mouseCallback(int button, int state, int x, int y)
{
    if (mouseEvent(button, state, x, y))
    {
        glutPostRedisplay();
    }
}

void mouseDragCallback(int x, int y)
{
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2((float)x, (float)y);

    glutPostRedisplay();
}

void mouseMoveCallback(int x, int y)
{
    ImGuiIO& io = ImGui::GetIO();
    io.MousePos = ImVec2((float)x, (float)y);

    glutPostRedisplay();
}

// xxxx //

int main(int argc, char *argv[])
{
  glutInit(&argc, argv);
  glutSetOption(GLUT_ACTION_ON_WINDOW_CLOSE, GLUT_ACTION_GLUTMAINLOOP_RETURNS);
  glutInitDisplayMode(GLUT_RGBA|GLUT_DEPTH|GLUT_DOUBLE|GLUT_MULTISAMPLE);

  glutInitWindowSize(1024, 768);
  glutCreateWindow("gcritic2");

  // callbacks
  glutDisplayFunc(drawScene);
  glutReshapeFunc(reshape);
  glutKeyboardFunc(keyboardCallback);
  glutSpecialFunc(KeyboardSpecial);
  glutMouseFunc(mouseCallback);
  glutMouseWheelFunc(mouseWheel);
  glutMotionFunc(mouseDragCallback);
  glutPassiveMotionFunc(mouseMoveCallback);

  glClearColor(0.447f, 0.565f, 0.604f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  ImGui_ImplGLUT_Init();

  glutMainLoop();

  ImGui_ImplGLUT_Shutdown();

  return 0;
}

