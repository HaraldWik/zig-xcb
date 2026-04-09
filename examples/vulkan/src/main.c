#define VK_USE_PLATFORM_XCB_KHR
#include <vulkan/vulkan.h>
#include <xcb/xcb.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    // --- XCB connection and window ---
    xcb_connection_t* connection = xcb_connect(NULL, NULL);
    if (xcb_connection_has_error(connection)) {
        fprintf(stderr, "Failed to connect to X server via XCB\n");
        return 1;
    }

    const xcb_setup_t* setup = xcb_get_setup(connection);
    xcb_screen_iterator_t iter = xcb_setup_roots_iterator(setup);
    xcb_screen_t* screen = iter.data;

    xcb_window_t window = xcb_generate_id(connection);

    uint32_t mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    uint32_t values[2] = { screen->white_pixel,
                           XCB_EVENT_MASK_EXPOSURE | XCB_EVENT_MASK_KEY_PRESS };

    xcb_create_window(connection, screen->root_depth, window, screen->root,
                      0, 0, 800, 600, 0,
                      XCB_WINDOW_CLASS_INPUT_OUTPUT,
                      screen->root_visual,
                      mask, values);

    xcb_map_window(connection, window);
    xcb_flush(connection);

    // --- Vulkan instance with XCB surface extension ---
    const char* instance_exts[] = {
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_KHR_XCB_SURFACE_EXTENSION_NAME,
    };

    VkInstance instance;
    VkInstanceCreateInfo inst_info = {};
    inst_info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    inst_info.enabledExtensionCount = 2;
    inst_info.ppEnabledExtensionNames = instance_exts;

    if (vkCreateInstance(&inst_info, NULL, &instance) != VK_SUCCESS) {
        fprintf(stderr, "Failed to create Vulkan instance\n");
        return 1;
    }

    // --- Create XCB surface ---
    VkSurfaceKHR surface;
    VkXcbSurfaceCreateInfoKHR surf_info = {};
    surf_info.sType = VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR;
    surf_info.connection = connection;
    surf_info.window     = window;

    if (vkCreateXcbSurfaceKHR(instance, &surf_info, NULL, &surface) != VK_SUCCESS) {
        fprintf(stderr, "Failed to create XCB Vulkan surface\n");
        return 1;
    }

    printf("Vulkan XCB surface created successfully!\n");

    // --- Pick first physical device ---
    uint32_t gpu_count = 0;
    vkEnumeratePhysicalDevices(instance, &gpu_count, NULL);
    if (gpu_count == 0) {
        fprintf(stderr, "No Vulkan GPUs found\n");
        return 1;
    }

    VkPhysicalDevice physical_devices[gpu_count];
    vkEnumeratePhysicalDevices(instance, &gpu_count, physical_devices);
    VkPhysicalDevice gpu = physical_devices[0];

    // --- Query surface capabilities ---
    VkSurfaceCapabilitiesKHR caps;
    if (vkGetPhysicalDeviceSurfaceCapabilitiesKHR(gpu, surface, &caps) != VK_SUCCESS) {
        fprintf(stderr, "Failed to get surface capabilities\n");
        return 1;
    }

    printf("Surface capabilities:\n");
    printf("  minImageCount = %u\n", caps.minImageCount);
    printf("  maxImageCount = %u\n", caps.maxImageCount);
    printf("  currentExtent = %ux%u\n", caps.currentExtent.width, caps.currentExtent.height);
    printf("  supportedUsageFlags = 0x%x\n", caps.supportedUsageFlags);

    // --- Cleanup ---
    vkDestroySurfaceKHR(instance, surface, NULL);
    vkDestroyInstance(instance, NULL);
    xcb_disconnect(connection);

    return 0;
}