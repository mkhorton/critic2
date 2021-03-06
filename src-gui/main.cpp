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

#include "imgui/imgui.h"
#include "imgui/imgui_impl_glfw.h"
#include "imgui/imgui_dock.h"

#include <GL/glu.h>
#include <GLFW/glfw3.h>
#include <stdio.h>
#include <stdlib.h>
#include "critic2.h"

using namespace std;

static void error_callback(int error, const char* description){
  fprintf(stderr, "Error %d: %s\n", error, description);
}

int main(int argc, char *argv[]){
  // Initialize
  glfwSetErrorCallback(error_callback);
  if (!glfwInit()) exit(EXIT_FAILURE);

  // Set up window
  GLFWwindow* window = glfwCreateWindow(1280, 720, "gcritic2", NULL, NULL);
  assert(window!=NULL);
  glfwMakeContextCurrent(window);

  // Initialize the critic2 library
  c2::gui_initialize((void *) window);

  // Setup ImGui binding
  ImGui_ImplGlfw_Init(window, true);

  // Main loop
  while (!glfwWindowShouldClose(window)){
    // New frame
    glfwPollEvents();
    ImGui_ImplGlfw_NewFrame();

    // Draw the GUI
    int menu_height = 0;
    if (ImGui::BeginMainMenuBar()){
      if (ImGui::BeginMenu("File")){
        if (ImGui::MenuItem("Quit","Ctrl+Q"))
          glfwSetWindowShouldClose(window, GLFW_TRUE);
        ImGui::EndMenu();
      }
      // xxxx //
      menu_height = ImGui::GetWindowSize().y;
      ImGui::EndMainMenuBar();
    }

    static bool show_scene1 = true;
    static bool show_scene2 = true;
    static bool show_scene3 = true;
    static bool show_scene4 = true;
    static bool show_scene5 = true;
    static bool show_scene6 = true;

    // if (show_scene6) {
    //   ImGui::SetNextWindowPos(ImVec2(10,20),ImGuiSetCond_Once);
    //   ImGui::SetNextWindowSize(ImVec2(500,500),ImGuiSetCond_Once);
    //   ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 0.01);
    //   ImGui::Container("contain",&show_scene6,ImGuiWindowFlags_NoTitleBar|ImGuiWindowFlags_NoMove|ImGuiWindowFlags_NoResize);
    //   ImGui::PopStyleVar();
    // }
    if (show_scene6) ImGui::Container("contain",&show_scene6);
    // ImGui::Container("contain");

    if (show_scene1){
      ImGui::SetNextWindowPos(ImVec2(10,20),ImGuiSetCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      if (ImGui::BeginDock("Info",&show_scene1)){
        ImGui::Text("Hello!");
        if (ImGui::Button("Button")){printf("Button\n");}
      }
      ImGui::EndDock();
    }
    if (show_scene2){
      ImGui::SetNextWindowPos(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      if (ImGui::BeginDock("Info2", &show_scene2,ImGuiWindowFlags_NoTitleBar)){
        ImGui::Text("Hello2!");
        if (ImGui::Button("Button2")){printf("Button2\n");}
      }
      ImGui::EndDock();
    }
    if (show_scene3){
      ImGui::SetNextWindowPos(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      if (ImGui::BeginDock("NoClose1")){
        ImGui::Text("Hello3!");
        if (ImGui::Button("Button3")){printf("Button3\n");}
      }
      ImGui::EndDock();
    }
    if (show_scene4){
      ImGui::SetNextWindowPos(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      if (ImGui::BeginDock("NoClose2")){
     ImGui::Text("Hello4!");
     if (ImGui::Button("Button4")){printf("Button4\n");}
      }
      ImGui::EndDock();
    }
    if (show_scene5){
      ImGui::SetNextWindowPos(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      ImGui::SetNextWindowSize(ImVec2(300,300),ImGuiSetCond_FirstUseEver);
      if (ImGui::BeginDock("Info5", &show_scene5)){
     ImGui::Text("Hello5!");
     if (ImGui::Button("Button5")){printf("Button5\n");}
      }
      ImGui::EndDock();
    }

    if (ImGui::Begin("justawindow")){
      ImGui::Print(); // print docking information
    }
    ImGui::EndDock();

    // Draw the current scene
    c2::draw_scene();

    // Render and swap
    ImGui::Render();
    glfwSwapBuffers(window);
  }

  // Cleanup
  ImGui::ShutdownDock();
  ImGui_ImplGlfw_Shutdown();
  glfwTerminate();

  return 0;
}

