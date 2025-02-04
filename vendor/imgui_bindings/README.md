Bindings generated using [](https://github.com/dearimgui/dear_bindings)

> **SSE needs to be disabled for ImGui**: Can be done by adding `#define IMGUI_DISABLE_SSE` to *imgui.h*

##### Used commands

```shel
python dear_bindings.py -o dcimgui ../imgui_bindings/imgui/imgui.h --custom-namespace-prefix ""
python dear_bindings.py --backend -o dcimgui_impl_glfw ../imgui_bindings/imgui/imgui_impl_glfw.h 
python dear_bindings.py --backend -o dcimgui_impl_opengl3 ../imgui_bindings/imgui/imgui_impl_opengl3.h
```

