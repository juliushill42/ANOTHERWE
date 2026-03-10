// src/lib.rs
// TITAN VISION OS - Rust Logic Engine
// Memory-Safe Nodal Orchestration
// Copyright © Julius Cameron Hill

use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use sysinfo::{ComponentExt, CpuExt, System, SystemExt};

// FFI Bridge to Zig Metal Layer
#[link(name = "titan_metal")]
extern "C" {
    fn apply_sharpen_node(buffer_ptr: *mut u8, len: usize, intensity: f32);
    fn apply_contrast_node(buffer_ptr: *mut u8, len: usize, contrast: f32, brightness: i32);
    fn apply_denoise_node(buffer_ptr: *mut u8, len: usize, width: u32, strength: u8);
}

// Node state management
#[derive(Clone, Debug)]
pub struct NodeConfig {
    pub sharpen: bool,
    pub sharpen_intensity: f32,
    pub denoise: bool,
    pub denoise_strength: u8,
    pub contrast: f32,
    pub brightness: i32,
    pub night_vision: bool,
    pub motion_detection: bool,
}

impl Default for NodeConfig {
    fn default() -> Self {
        NodeConfig {
            sharpen: false,
            sharpen_intensity: 1.0,
            denoise: false,
            denoise_strength: 50,
            contrast: 1.0,
            brightness: 0,
            night_vision: false,
            motion_detection: false,
        }
    }
}

// System telemetry
#[repr(C)]
#[derive(Debug, Clone)]
pub struct TitanVitals {
    pub cpu_temp: f32,
    pub cpu_usage: f32,
    pub mem_usage: f32,
    pub fps: i32,
}

// Main processing engine
pub struct TitanEngine {
    pub config: Arc<Mutex<NodeConfig>>,
    vitals: Arc<Mutex<TitanVitals>>,
    system: Arc<Mutex<System>>,
}

impl TitanEngine {
    pub fn new() -> Self {
        TitanEngine {
            config: Arc::new(Mutex::new(NodeConfig::default())),
            vitals: Arc::new(Mutex::new(TitanVitals {
                cpu_temp: 0.0,
                cpu_usage: 0.0,
                mem_usage: 0.0,
                fps: 60,
            })),
            system: Arc::new(Mutex::new(System::new_all())),
        }
    }

    // Apply nodal processing pipeline
    pub fn process_frame(&self, buffer: &mut [u8], width: u32, height: u32) {
        let config = self.config.lock().unwrap().clone();
        let len = buffer.len();

        unsafe {
            // Node 1: Contrast & Brightness
            if config.contrast != 1.0 || config.brightness != 0 {
                apply_contrast_node(
                    buffer.as_mut_ptr(),
                    len,
                    config.contrast,
                    config.brightness,
                );
            }

            // Node 2: Sharpening
            if config.sharpen {
                apply_sharpen_node(buffer.as_mut_ptr(), len, config.sharpen_intensity);
            }

            // Node 3: Denoising
            if config.denoise {
                apply_denoise_node(buffer.as_mut_ptr(), len, width, config.denoise_strength);
            }

            // Node 4: Night Vision (Implemented in Rust for simplicity)
            if config.night_vision {
                self.apply_night_vision(buffer, width, height);
            }
        }
    }

    // Night Vision node (Green phosphor effect)
    fn apply_night_vision(&self, buffer: &mut [u8], width: u32, height: u32) {
        for y in 0..height {
            for x in 0..width {
                let idx = ((y * width + x) * 4) as usize;
                if idx + 2 < buffer.len() {
                    // Convert to grayscale
                    let gray = ((buffer[idx] as u32 + buffer[idx + 1] as u32 + buffer[idx + 2] as u32) / 3) as u8;
                    
                    // Amplify and apply green tint
                    let amplified = ((gray as u32 * 150) / 100).min(255) as u8;
                    buffer[idx] = 0;                    // R
                    buffer[idx + 1] = amplified;        // G
                    buffer[idx + 2] = 0;                // B
                }
            }
        }
    }

    // Monitor system health
    pub fn start_telemetry_monitor(&self) {
        let vitals = Arc::clone(&self.vitals);
        let system = Arc::clone(&self.system);
        let config = Arc::clone(&self.config);

        thread::spawn(move || loop {
            let mut sys = system.lock().unwrap();
            sys.refresh_all();

            let temp = sys
                .components()
                .iter()
                .find(|c| c.label().contains("CPU") || c.label().contains("Core"))
                .map(|c| c.temperature())
                .unwrap_or(0.0);

            let cpu_usage = sys.global_cpu_info().cpu_usage();
            let mem_usage = (sys.used_memory() as f32 / sys.total_memory() as f32) * 100.0;

            // Proactive thermal throttling
            if temp > 85.0 {
                let mut cfg = config.lock().unwrap();
                cfg.denoise = false; // Disable heavy processing
                println!("⚠️  CRITICAL HEAT: Disabling denoise node ({}°C)", temp);
            }

            {
                let mut v = vitals.lock().unwrap();
                v.cpu_temp = temp;
                v.cpu_usage = cpu_usage;
                v.mem_usage = mem_usage;
            }

            thread::sleep(Duration::from_secs(2));
        });
    }

    pub fn get_vitals(&self) -> TitanVitals {
        self.vitals.lock().unwrap().clone()
    }

    pub fn update_config(&self, new_config: NodeConfig) {
        let mut config = self.config.lock().unwrap();
        *config = new_config;
    }
}

// Export for FFI
#[no_mangle]
pub extern "C" fn titan_engine_new() -> *mut TitanEngine {
    Box::into_raw(Box::new(TitanEngine::new()))
}

#[no_mangle]
pub extern "C" fn titan_engine_get_vitals(engine: *mut TitanEngine) -> TitanVitals {
    let engine = unsafe { &*engine };
    engine.get_vitals()
}

#[no_mangle]
pub extern "C" fn titan_engine_process_frame(
    engine: *mut TitanEngine,
    buffer: *mut u8,
    len: usize,
    width: u32,
    height: u32,
) {
    let engine = unsafe { &*engine };
    let buffer_slice = unsafe { std::slice::from_raw_parts_mut(buffer, len) };
    engine.process_frame(buffer_slice, width, height);
}
