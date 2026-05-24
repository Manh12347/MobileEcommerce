package com.example.ecommerce.controller;

import com.example.ecommerce.util.SecurityUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/v1/api/uploads")
@CrossOrigin(origins = "*")
@Slf4j
public class FileController {

    private static final List<String> ALLOWED_IMAGE_TYPES = Arrays.asList(
            "image/jpeg", "image/png", "image/gif", "image/webp", "image/svg+xml"
    );

    private static final long MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

    @Value("${app.base-url:https://doantrang.online}")
    private String baseUrl;

    private String getUploadDir(String type) {
        String dir = System.getProperty("user.dir") + "/uploads/" + type;
        try {
            Path path = Paths.get(dir);
            if (!Files.exists(path)) {
                Files.createDirectories(path);
            }
        } catch (IOException e) {
            log.error("Failed to create upload directory: {}", dir, e);
        }
        return dir;
    }

    @PostMapping("/users")
    public ResponseEntity<?> uploadUserFile(@RequestParam("file") MultipartFile file) {
        return handleUpload(file, "users");
    }

    @PostMapping("/products")
    public ResponseEntity<?> uploadProductFile(@RequestParam("file") MultipartFile file) {
        return handleUpload(file, "products");
    }

    private ResponseEntity<?> handleUpload(MultipartFile file, String type) {
        try {
            if (file.isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(new ApiErrorResponse(false, "File không được để trống"));
            }

            if (file.getSize() > MAX_FILE_SIZE) {
                return ResponseEntity.badRequest()
                        .body(new ApiErrorResponse(false, "File vượt quá kích thước cho phép (tối đa 5MB)"));
            }

            String contentType = file.getContentType();
            if (contentType == null || !ALLOWED_IMAGE_TYPES.contains(contentType)) {
                return ResponseEntity.badRequest()
                        .body(new ApiErrorResponse(false, "Chỉ chấp nhận file ảnh (JPEG, PNG, GIF, WEBP, SVG)"));
            }

            String uploadDir = getUploadDir(type);
            String originalFilename = file.getOriginalFilename();
            String extension = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                extension = originalFilename.substring(originalFilename.lastIndexOf("."));
            }
            String newFilename = UUID.randomUUID().toString() + extension;

            Path targetPath = Paths.get(uploadDir, newFilename);
            Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);

            String fileUrl = baseUrl + "/v1/api/uploads/" + type + "/" + newFilename;
            log.info("File uploaded successfully: {} -> {}", type, newFilename);

            return ResponseEntity.ok(new ApiFileResponse(true, "Upload thành công", fileUrl, newFilename));

        } catch (IOException e) {
            log.error("Failed to upload file for type: {}", type, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiErrorResponse(false, "Lỗi khi lưu file: " + e.getMessage()));
        }
    }

    @GetMapping("/users/{filename:.+}")
    public ResponseEntity<Resource> getUserFile(@PathVariable String filename) {
        return serveFile("users", filename);
    }

    @GetMapping("/products/{filename:.+}")
    public ResponseEntity<Resource> getProductFile(@PathVariable String filename) {
        return serveFile("products", filename);
    }

    private ResponseEntity<Resource> serveFile(String type, String filename) {
        try {
            Path filePath = Paths.get(getUploadDir(type)).resolve(filename).normalize();
            Resource resource = new UrlResource(filePath.toUri());

            if (resource.exists() && resource.isReadable()) {
                String contentType = Files.probeContentType(filePath);
                if (contentType == null) {
                    contentType = "application/octet-stream";
                }
                return ResponseEntity.ok()
                        .contentType(MediaType.parseMediaType(contentType))
                        .body(resource);
            } else {
                return ResponseEntity.notFound().build();
            }
        } catch (MalformedURLException e) {
            log.error("File not found: {}", filename, e);
            return ResponseEntity.notFound().build();
        } catch (IOException e) {
            log.error("Error reading file: {}", filename, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @lombok.Data
    @lombok.AllArgsConstructor
    private static class ApiFileResponse {
        private boolean success;
        private String message;
        private String url;
        private String filename;
    }

    @lombok.Data
    @lombok.AllArgsConstructor
    private static class ApiErrorResponse {
        private boolean success;
        private String message;
    }
}
