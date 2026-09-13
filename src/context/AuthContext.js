"use client";

import React, { createContext, useContext, useState, useEffect } from "react";
import { db, ref, set, get } from "@/lib/firebase";

const AuthContext = createContext();

export const DEFAULT_USERS = {
  admin: {
    username: "admin",
    password: "123",
    role: "ADMIN",
    name: "Lê Triệu Bá Vương (Admin)",
    phone: "0905123456",
    subject: "Tất cả môn",
  },
  teacher: {
    username: "teacher",
    password: "123",
    role: "TEACHER",
    name: "Thầy Vương (Giáo viên)",
    phone: "0905999888",
    subject: "TOAN",
  },
  student: {
    username: "student",
    password: "123",
    role: "STUDENT",
    name: "Nguyễn Văn An (Học sinh Khối 9)",
    phone: "0912345678",
    classId: "1", // Lớp 9A1
  },
};

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Restore session from localStorage if available
    const savedUser = localStorage.getItem("tuition_user");
    if (savedUser) {
      try {
        setUser(JSON.parse(savedUser));
      } catch (e) {
        console.error("Lỗi parse thông tin đăng nhập:", e);
      }
    } else {
      // Default to Admin session so current workflow is seamless, or require login
      // For immediate convenience, set default user to Admin if none stored
      const defaultSession = DEFAULT_USERS.admin;
      setUser(defaultSession);
      localStorage.setItem("tuition_user", JSON.stringify(defaultSession));
    }
    setLoading(false);
  }, []);

  const login = (userData) => {
    setUser(userData);
    localStorage.setItem("tuition_user", JSON.stringify(userData));
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem("tuition_user");
  };

  return (
    <AuthContext.Provider value={{ user, setUser, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
