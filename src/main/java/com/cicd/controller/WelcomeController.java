package com.cicd.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class WelcomeController {
    @GetMapping("/")
    public String welcome(HttpServletRequest request, Model model) {
        // 클라이언트가 접근한 서버의 IP를 가져옴
        String serverIp = request.getServerName();
        model.addAttribute("serverIp", serverIp);
        return "welcome";
    }
}
