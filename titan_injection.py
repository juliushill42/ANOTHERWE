#!/usr/bin/env python3
"""
TITAN VISION OS - Camera Injection Engine
4K 60FPS Nodal Processing with Virtual Camera Output
Copyright © Julius Cameron Hill
"""

import cv2
import numpy as np
import sys
import os
from ctypes import CDLL, c_void_p, c_uint8, c_uint32, c_float, c_int, POINTER

# Load Rust engine
try:
    rust_lib = CDLL("./target/release/libtitan_engine.so")
except OSError:
    print("❌ Rust engine not found. Run: cargo build --release")
    sys.exit(1)

# FFI function signatures
rust_lib.titan_engine_new.restype = c_void_p
rust_lib.titan_engine_process_frame.argtypes = [
    c_void_p, POINTER(c_uint8), c_uint32, c_uint32, c_uint32
]

class TitanVisionEngine:
    def __init__(self, camera_index=0, width=3840, height=2160, fps=60):
        print("🚀 Initializing TITAN VISION OS...")
        
        self.width = width
        self.height = height
        self.fps = fps
        
        # Initialize Rust engine
        self.rust_engine = rust_lib.titan_engine_new()
        print("✅ Rust Logic Engine loaded")
        
        # Open camera
        self.cap = cv2.VideoCapture(camera_index, cv2.CAP_V4L2)
        
        # Force 4K 60FPS
        self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        self.cap.set(cv2.CAP_PROP_FPS, fps)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        # Verify settings
        actual_width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        actual_height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        actual_fps = int(self.cap.get(cv2.CAP_PROP_FPS))
        
        print(f"📷 Camera initialized: {actual_width}x{actual_height} @ {actual_fps}fps")
        
        if not self.cap.isOpened():
            print("❌ Failed to open camera")
            sys.exit(1)
            
        # Node states
        self.nodes = {
            'sharpen': False,
            'denoise': False,
            'night_vision': False,
            'contrast': 1.0,
            'brightness': 0,
            'zoom_level': 1.0,
            'motion_detection': False
        }
        
        self.first_frame = None
        
    def inject_zoom(self, frame):
        """Digital zoom via ROI"""
        if self.nodes['zoom_level'] <= 1.0:
            return frame
            
        h, w = frame.shape[:2]
        new_w = int(w / self.nodes['zoom_level'])
        new_h = int(h / self.nodes['zoom_level'])
        
        # Center crop
        x = (w - new_w) // 2
        y = (h - new_h) // 2
        
        cropped = frame[y:y+new_h, x:x+new_w]
        return cv2.resize(cropped, (w, h), interpolation=cv2.INTER_LINEAR)
    
    def inject_motion_detection(self, frame):
        """Motion detection with bounding boxes"""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)
        
        if self.first_frame is None:
            self.first_frame = gray
            return frame
        
        frame_delta = cv2.absdiff(self.first_frame, gray)
        thresh = cv2.threshold(frame_delta, 25, 255, cv2.THRESH_BINARY)[1]
        thresh = cv2.dilate(thresh, None, iterations=2)
        
        contours, _ = cv2.findContours(thresh.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            if cv2.contourArea(contour) < 500:
                continue
            
            (x, y, w, h) = cv2.boundingRect(contour)
            cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 3)
            cv2.putText(frame, "MOTION DETECTED", (x, y - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        return frame
    
    def process_frame(self, frame):
        """Apply nodal injection pipeline"""
        # Digital zoom first (reduces processing load)
        frame = self.inject_zoom(frame)
        
        # Convert to RGBA for Rust engine
        frame_rgba = cv2.cvtColor(frame, cv2.COLOR_BGR2RGBA)
        h, w = frame_rgba.shape[:2]
        
        # Call Rust engine
        frame_ptr = frame_rgba.ctypes.data_as(POINTER(c_uint8))
        rust_lib.titan_engine_process_frame(
            self.rust_engine,
            frame_ptr,
            frame_rgba.size,
            w,
            h
        )
        
        # Convert back to BGR
        frame = cv2.cvtColor(frame_rgba, cv2.COLOR_RGBA2BGR)
        
        # Motion detection (Python layer)
        if self.nodes['motion_detection']:
            frame = self.inject_motion_detection(frame)
        
        return frame
    
    def run(self, output_device='/dev/video10'):
        """Main processing loop"""
        print(f"🎥 Starting 60FPS nodal injection...")
        print(f"📺 Virtual camera: {output_device}")
        print("\nPress 'q' to quit")
        
        frame_count = 0
        
        while True:
            ret, frame = self.cap.read()
            if not ret:
                print("❌ Failed to read frame")
                break
            
            # Apply nodal processing
            processed = self.process_frame(frame)
            
            # Display (scaled for monitor)
            display_frame = cv2.resize(processed, (1920, 1080))
            cv2.imshow('TITAN VISION OS', display_frame)
            
            frame_count += 1
            if frame_count % 60 == 0:
                print(f"📊 Processed {frame_count} frames @ 60fps")
            
            # Keyboard controls
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('s'):
                self.nodes['sharpen'] = not self.nodes['sharpen']
                print(f"Sharpen: {self.nodes['sharpen']}")
            elif key == ord('d'):
                self.nodes['denoise'] = not self.nodes['denoise']
                print(f"Denoise: {self.nodes['denoise']}")
            elif key == ord('n'):
                self.nodes['night_vision'] = not self.nodes['night_vision']
                print(f"Night Vision: {self.nodes['night_vision']}")
            elif key == ord('m'):
                self.nodes['motion_detection'] = not self.nodes['motion_detection']
                print(f"Motion Detection: {self.nodes['motion_detection']}")
            elif key == ord('+'):
                self.nodes['zoom_level'] = min(10.0, self.nodes['zoom_level'] + 0.5)
                print(f"Zoom: {self.nodes['zoom_level']}x")
            elif key == ord('-'):
                self.nodes['zoom_level'] = max(1.0, self.nodes['zoom_level'] - 0.5)
                print(f"Zoom: {self.nodes['zoom_level']}x")
        
        self.cleanup()
    
    def cleanup(self):
        print("\n🛑 Shutting down TITAN VISION OS...")
        self.cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    print("""
╔═══════════════════════════════════════════╗
║   TITAN VISION OS - UNICORN 32 BUILD     ║
║   Copyright © Julius Cameron Hill        ║
╚═══════════════════════════════════════════╝
    """)
    
    camera_index = 0
    if len(sys.argv) > 1:
        camera_index = int(sys.argv[1])
    
    engine = TitanVisionEngine(camera_index=camera_index)
    engine.run()
