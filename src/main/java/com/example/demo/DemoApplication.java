package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;

@SpringBootApplication
@RestController
public class DemoApplication {

    private int requestCount = 0;

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @GetMapping("/hello")
    public String hello() {
        requestCount++;
        return "Hello, World!";
    }

    @GetMapping("/metrics")
    public String metrics() {
        return "Request Count: " + requestCount;
    }
}

