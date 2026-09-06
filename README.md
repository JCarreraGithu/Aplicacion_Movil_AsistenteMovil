##Sistema Inteligente de Monitoreo y Riego para Jardines

Aplicación móvil multiplataforma para el cuidado, gestión e identificación de jardines domésticos mediante Inteligencia Artificial y
control de IoT integrado.

##Características Principales
Asistente Inteligente con IA (Google Gemini API): Consultas personalizadas en tiempo real sobre el cuidado, diagnóstico de enfermedades
y tratamientos para especies botánicas.

Reconocimiento Botánico (PlantNet API): Identificación automática de plantas a partir de captura o carga de fotografías.

Monitoreo IoT y Riego Automatizado (ESP32): Lectura de sensores en tiempo real (humedad del suelo, temperatura,
humedad ambiental, iluminación) y control remoto de bombas/mangueras de riego.

Inventario de Jardines y Sectores: Gestión organizada de especies por zonas dentro del hogar.

Historial de Consultas: Registro persistente de diagnósticos y recomendaciones emitidas por la IA.

##Tecnologías Utilizadas
Frontend (Mobile App)
Flutter (Dart)

Image Picker (Captura y selección de imágenes)

HTTP (Consumo de servicios REST API)

Backend (API REST)
Node.js con Express.js

JWT (JSON Web Tokens) & Bcrypt (Autenticación y seguridad)

Multer (Procesamiento y almacenamiento de archivos multimedia)

Base de Datos
PostgreSQL (Persistencia relacional de usuarios, sectores, inventario e historial)

Hardware / IoT
Microcontrolador ESP32

Sensores de humedad de suelo, temperatura/humedad ambiental y fotoresistencia

Módulos de relé, electroválvulas y bombas de agua
