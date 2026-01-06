# Shoutout Usage Guide 📚

A comprehensive guide with real-world examples for using Shoutout with Frappe/ERPNext applications.

---

## Table of Contents

1. [Basic Setup](#basic-setup)
2. [Authentication Patterns](#authentication-patterns)
3. [E-Commerce Application](#e-commerce-application)
4. [Education Management System](#education-management-system)
5. [Healthcare Application](#healthcare-application)
6. [Project Management Tool](#project-management-tool)
7. [Real Estate Platform](#real-estate-platform)
8. [Restaurant/Food Delivery](#restaurant-food-delivery)
9. [Advanced Patterns](#advanced-patterns)
10. [Error Handling Strategies](#error-handling-strategies)
11. [Testing](#testing)
12. [Performance Optimization](#performance-optimization)

---

## Basic Setup

### Initial Configuration

```dart
import 'package:shoutout/shoutout.dart';

// Development environment
final devConfig = ShoutoutConfig(
  baseUrl: 'https://dev.yoursite.com',
  connectTimeout: Duration(seconds: 60),
  maxRetries: 5,
  enableLogging: true,
  enableNetworkLogging: true,
);

// Production environment
final prodConfig = ShoutoutConfig(
  baseUrl: 'https://yoursite.com',
  connectTimeout: Duration(seconds: 30),
  maxRetries: 3,
  enableLogging: true,
  enableNetworkLogging: false, // Disable in production
);

// Initialize client
final client = ShoutoutClient(
  config: isProduction ? prodConfig : devConfig,
);
```

---

## Authentication Patterns

### 1. Login with Username/Password

```dart
class AuthService {
  final ShoutoutClient client;

  AuthService(this.client);

  Future<UserSession> login(String username, String password) async {
    try {
      // Call Frappe login method
      final response = await client.callMethod<Map<String, dynamic>>(
        'login',
        params: {
          'usr': username,
          'pwd': password,
        },
      );

      // Extract session info
      final token = response['token'] as String?;
      final userId = response['user'] as String?;

      if (token != null) {
        // Set token for future requests
        client.setToken(token);
      }

      return UserSession(
        userId: userId!,
        token: token!,
        fullName: response['full_name'] as String,
      );
    } on AuthenticationException catch (e) {
      throw AuthFailedException('Invalid credentials');
    }
  }

  Future<void> logout() async {
    await client.callMethod('logout');
    client.clearAuth();
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return await client.callMethod('frappe.auth.get_logged_user');
  }
}

class UserSession {
  final String userId;
  final String token;
  final String fullName;

  UserSession({
    required this.userId,
    required this.token,
    required this.fullName,
  });
}
```

### 2. API Key Authentication

```dart
class ApiAuthService {
  final ShoutoutClient client;
  final SecureStorage storage;

  ApiAuthService(this.client, this.storage);

  Future<void> authenticateWithApiKey() async {
    final apiKey = await storage.read('api_key');
    final apiSecret = await storage.read('api_secret');

    if (apiKey != null && apiSecret != null) {
      client.setApiCredentials(apiKey, apiSecret);
    }
  }

  Future<void> saveApiCredentials(String key, String secret) async {
    await storage.write('api_key', key);
    await storage.write('api_secret', secret);
    client.setApiCredentials(key, secret);
  }
}
```

---

## E-Commerce Application

### Product Catalog Service

```dart
class ProductService {
  final ShoutoutClient client;

  ProductService(this.client);

  // Get featured products
  Future<List<Product>> getFeaturedProducts() async {
    final products = await client.getList(
      'Item',
      fields: [
        'name',
        'item_name',
        'item_code',
        'description',
        'image',
        'standard_rate',
        'stock_qty',
        'brand',
        'item_group',
      ],
      filters: {
        'is_stock_item': 1,
        'disabled': 0,
        'featured': 1,
      },
      limitPageLength: 20,
      orderBy: 'modified desc',
    );

    return products.map((p) => Product.fromJson(p)).toList();
  }

  // Search products
  Future<List<Product>> searchProducts(String query, {
    String? category,
    double? minPrice,
    double? maxPrice,
    int page = 1,
  }) async {
    final filters = <String, dynamic>{
      'disabled': 0,
    };

    if (query.isNotEmpty) {
      filters['item_name'] = ['like', '%$query%'];
    }

    if (category != null) {
      filters['item_group'] = category;
    }

    if (minPrice != null) {
      filters['standard_rate'] = ['>=', minPrice];
    }

    if (maxPrice != null) {
      filters['standard_rate'] = ['<=', maxPrice];
    }

    final products = await client.getList(
      'Item',
      fields: [
        'name',
        'item_name',
        'item_code',
        'image',
        'standard_rate',
        'item_group',
        'brand',
      ],
      filters: filters,
      limitStart: (page - 1) * 20,
      limitPageLength: 20,
      orderBy: 'item_name asc',
    );

    return products.map((p) => Product.fromJson(p)).toList();
  }

  // Get product details
  Future<Product> getProductDetails(String itemCode) async {
    final product = await client.getDoc(
      'Item',
      itemCode,
      fields: [
        'name',
        'item_name',
        'item_code',
        'description',
        'image',
        'website_image',
        'standard_rate',
        'stock_qty',
        'brand',
        'item_group',
        'has_variants',
        'attributes',
        'weight_per_unit',
        'weight_uom',
      ],
    );

    return Product.fromJson(product);
  }

  // Get product variants
  Future<List<Product>> getProductVariants(String template) async {
    final variants = await client.getList(
      'Item',
      fields: ['name', 'item_name', 'variant_of', 'attributes'],
      filters: {'variant_of': template},
    );

    return variants.map((v) => Product.fromJson(v)).toList();
  }
}
```

### Shopping Cart Service

```dart
class CartService {
  final ShoutoutClient client;

  CartService(this.client);

  // Add item to cart
  Future<void> addToCart(String itemCode, int quantity) async {
    await client.callMethod(
      'erpnext.shopping_cart.cart.add_to_cart',
      params: {
        'item_code': itemCode,
        'qty': quantity,
      },
    );
  }

  // Get cart
  Future<Cart> getCart() async {
    final cart = await client.callMethod<Map<String, dynamic>>(
      'erpnext.shopping_cart.cart.get_cart_quotation',
    );

    return Cart.fromJson(cart);
  }

  // Update cart item
  Future<void> updateCartItem(String itemCode, int quantity) async {
    await client.callMethod(
      'erpnext.shopping_cart.cart.update_cart',
      params: {
        'item_code': itemCode,
        'qty': quantity,
      },
    );
  }

  // Remove from cart
  Future<void> removeFromCart(String itemCode) async {
    await client.callMethod(
      'erpnext.shopping_cart.cart.update_cart',
      params: {
        'item_code': itemCode,
        'qty': 0,
      },
    );
  }

  // Apply coupon
  Future<void> applyCoupon(String couponCode) async {
    await client.callMethod(
      'erpnext.shopping_cart.cart.apply_coupon_code',
      params: {'coupon_code': couponCode},
    );
  }
}
```

### Order Service

```dart
class OrderService {
  final ShoutoutClient client;

  OrderService(this.client);

  // Create order
  Future<String> createOrder(OrderData orderData) async {
    final order = await client.createDoc(
      'Sales Order',
      data: {
        'customer': orderData.customerId,
        'delivery_date': orderData.deliveryDate,
        'items': orderData.items.map((item) => {
          'item_code': item.itemCode,
          'qty': item.quantity,
          'rate': item.rate,
        }).toList(),
        'shipping_address': orderData.shippingAddress,
        'billing_address': orderData.billingAddress,
      },
    );

    return order['name'];
  }

  // Get order history
  Future<List<Order>> getOrderHistory(String customerId) async {
    final orders = await client.getList(
      'Sales Order',
      fields: [
        'name',
        'transaction_date',
        'status',
        'grand_total',
        'delivery_status',
      ],
      filters: {
        'customer': customerId,
        'docstatus': ['!=', 2], // Not cancelled
      },
      limitPageLength: 50,
      orderBy: 'transaction_date desc',
    );

    return orders.map((o) => Order.fromJson(o)).toList();
  }

  // Get order details
  Future<Order> getOrderDetails(String orderId) async {
    final order = await client.getDoc(
      'Sales Order',
      orderId,
      fields: [
        'name',
        'customer',
        'customer_name',
        'transaction_date',
        'delivery_date',
        'status',
        'items',
        'grand_total',
        'delivery_status',
        'shipping_address_name',
        'billing_address_name',
      ],
    );

    return Order.fromJson(order);
  }

  // Track order
  Future<OrderTracking> trackOrder(String orderId) async {
    final tracking = await client.callMethod<Map<String, dynamic>>(
      'erpnext.selling.doctype.sales_order.sales_order.get_delivery_status',
      params: {'sales_order': orderId},
    );

    return OrderTracking.fromJson(tracking);
  }
}
```

---

## Education Management System

### Course Service

```dart
class CourseService {
  final ShoutoutClient client;

  CourseService(this.client);

  // Get available courses
  Future<List<Course>> getCourses({
    String? category,
    String? instructor,
    String? level,
  }) async {
    final filters = <String, dynamic>{
      'published': 1,
      'status': 'Active',
    };

    if (category != null) filters['category'] = category;
    if (instructor != null) filters['instructor'] = instructor;
    if (level != null) filters['level'] = level;

    final courses = await client.getList(
      'LMS Course',
      fields: [
        'name',
        'title',
        'short_introduction',
        'image',
        'instructor',
        'instructor_name',
        'category',
        'level',
        'duration',
        'price',
        'rating',
        'enrolled_students',
      ],
      filters: filters,
      limitPageLength: 20,
      orderBy: 'rating desc',
    );

    return courses.map((c) => Course.fromJson(c)).toList();
  }

  // Get course details
  Future<Course> getCourseDetails(String courseId) async {
    final course = await client.getDoc(
      'LMS Course',
      courseId,
      fields: [
        'name',
        'title',
        'short_introduction',
        'description',
        'image',
        'video_link',
        'instructor',
        'instructor_name',
        'instructor.bio',
        'category',
        'level',
        'duration',
        'price',
        'rating',
        'enrolled_students',
        'chapters',
        'prerequisites',
        'learning_outcomes',
      ],
    );

    return Course.fromJson(course);
  }

  // Enroll in course
  Future<void> enrollCourse(String courseId, String studentId) async {
    await client.createDoc(
      'LMS Enrollment',
      data: {
        'course': courseId,
        'student': studentId,
        'enrollment_date': DateTime.now().toIso8601String(),
        'status': 'Active',
      },
    );
  }

  // Get enrolled courses
  Future<List<Course>> getEnrolledCourses(String studentId) async {
    final enrollments = await client.getList(
      'LMS Enrollment',
      fields: [
        'course',
        'course.title',
        'course.image',
        'course.instructor_name',
        'progress',
        'enrollment_date',
      ],
      filters: {
        'student': studentId,
        'status': 'Active',
      },
      orderBy: 'enrollment_date desc',
    );

    return enrollments.map((e) => Course.fromEnrollment(e)).toList();
  }

  // Update course progress
  Future<void> updateProgress(
    String enrollmentId,
    String chapterId,
    bool completed,
  ) async {
    await client.callMethod(
      'lms.api.update_course_progress',
      params: {
        'enrollment': enrollmentId,
        'chapter': chapterId,
        'completed': completed,
      },
    );
  }
}
```

### Student Service

```dart
class StudentService {
  final ShoutoutClient client;

  StudentService(this.client);

  // Get student profile
  Future<Student> getStudentProfile(String studentId) async {
    final student = await client.getDoc(
      'Student',
      studentId,
      fields: [
        'name',
        'first_name',
        'last_name',
        'student_name',
        'student_email_id',
        'date_of_birth',
        'joining_date',
        'student_mobile_number',
        'program',
        'student_batch_name',
      ],
    );

    return Student.fromJson(student);
  }

  // Get attendance
  Future<List<Attendance>> getAttendance(
    String studentId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final filters = <String, dynamic>{
      'student': studentId,
    };

    if (fromDate != null) {
      filters['attendance_date'] = ['>=', fromDate.toIso8601String()];
    }
    if (toDate != null) {
      filters['attendance_date'] = ['<=', toDate.toIso8601String()];
    }

    final attendance = await client.getList(
      'Student Attendance',
      fields: [
        'name',
        'attendance_date',
        'status',
        'course_schedule',
        'course_schedule.course',
      ],
      filters: filters,
      orderBy: 'attendance_date desc',
    );

    return attendance.map((a) => Attendance.fromJson(a)).toList();
  }

  // Get grades
  Future<List<Grade>> getGrades(String studentId) async {
    final grades = await client.getList(
      'Assessment Result',
      fields: [
        'name',
        'assessment',
        'assessment.assessment_name',
        'assessment.course',
        'score',
        'grade',
        'grading_scale',
      ],
      filters: {'student': studentId},
      orderBy: 'creation desc',
    );

    return grades.map((g) => Grade.fromJson(g)).toList();
  }

  // Submit assignment
  Future<void> submitAssignment(
    String assignmentId,
    String studentId,
    String submissionUrl,
  ) async {
    await client.createDoc(
      'Assignment Submission',
      data: {
        'assignment': assignmentId,
        'student': studentId,
        'submission_date': DateTime.now().toIso8601String(),
        'submission_url': submissionUrl,
        'status': 'Submitted',
      },
    );
  }
}
```

---

## Healthcare Application

### Patient Service

```dart
class PatientService {
  final ShoutoutClient client;

  PatientService(this.client);

  // Register patient
  Future<String> registerPatient(PatientData data) async {
    final patient = await client.createDoc(
      'Patient',
      data: {
        'first_name': data.firstName,
        'last_name': data.lastName,
        'sex': data.gender,
        'dob': data.dateOfBirth,
        'mobile': data.mobile,
        'email': data.email,
        'blood_group': data.bloodGroup,
        'patient_name': '${data.firstName} ${data.lastName}',
      },
    );

    return patient['name'];
  }

  // Get patient profile
  Future<Patient> getPatientProfile(String patientId) async {
    final patient = await client.getDoc(
      'Patient',
      patientId,
      fields: [
        'name',
        'patient_name',
        'sex',
        'dob',
        'age',
        'blood_group',
        'mobile',
        'email',
        'image',
        'allergies',
        'medical_history',
      ],
    );

    return Patient.fromJson(patient);
  }

  // Get patient appointments
  Future<List<Appointment>> getAppointments(
    String patientId, {
    String? status,
  }) async {
    final filters = <String, dynamic>{
      'patient': patientId,
    };

    if (status != null) {
      filters['status'] = status;
    }

    final appointments = await client.getList(
      'Patient Appointment',
      fields: [
        'name',
        'appointment_date',
        'appointment_time',
        'practitioner',
        'practitioner_name',
        'department',
        'status',
        'duration',
        'invoiced',
      ],
      filters: filters,
      orderBy: 'appointment_date desc, appointment_time desc',
    );

    return appointments.map((a) => Appointment.fromJson(a)).toList();
  }

  // Book appointment
  Future<String> bookAppointment({
    required String patientId,
    required String practitionerId,
    required DateTime appointmentDate,
    required String appointmentTime,
    String? notes,
  }) async {
    final appointment = await client.createDoc(
      'Patient Appointment',
      data: {
        'patient': patientId,
        'practitioner': practitionerId,
        'appointment_date': appointmentDate.toIso8601String().split('T')[0],
        'appointment_time': appointmentTime,
        'status': 'Open',
        'notes': notes,
      },
    );

    return appointment['name'];
  }

  // Get medical records
  Future<List<MedicalRecord>> getMedicalRecords(String patientId) async {
    final records = await client.getList(
      'Patient Medical Record',
      fields: [
        'name',
        'patient',
        'practitioner',
        'practitioner_name',
        'communication_date',
        'note',
        'reference_doctype',
        'reference_name',
      ],
      filters: {'patient': patientId},
      orderBy: 'communication_date desc',
    );

    return records.map((r) => MedicalRecord.fromJson(r)).toList();
  }
}
```

### Doctor/Practitioner Service

```dart
class PractitionerService {
  final ShoutoutClient client;

  PractitionerService(this.client);

  // Get available doctors
  Future<List<Practitioner>> getAvailablePractitioners({
    String? department,
    String? specialization,
  }) async {
    final filters = <String, dynamic>{
      'status': 'Active',
    };

    if (department != null) filters['department'] = department;
    if (specialization != null) filters['specialization'] = specialization;

    final practitioners = await client.getList(
      'Healthcare Practitioner',
      fields: [
        'name',
        'practitioner_name',
        'department',
        'specialization',
        'mobile_phone',
        'image',
        'designation',
      ],
      filters: filters,
    );

    return practitioners.map((p) => Practitioner.fromJson(p)).toList();
  }

  // Get practitioner schedule
  Future<List<TimeSlot>> getPractitionerSchedule(
    String practitionerId,
    DateTime date,
  ) async {
    final schedule = await client.callMethod<List>(
      'erpnext.healthcare.doctype.patient_appointment.patient_appointment.get_availability_data',
      params: {
        'practitioner': practitionerId,
        'date': date.toIso8601String().split('T')[0],
      },
    );

    return schedule.map((s) => TimeSlot.fromJson(s as Map<String, dynamic>)).toList();
  }
}
```

---

## Project Management Tool

### Project Service

```dart
class ProjectService {
  final ShoutoutClient client;

  ProjectService(this.client);

  // Get projects
  Future<List<Project>> getProjects({
    String? status,
    String? teamMember,
  }) async {
    final filters = <String, dynamic>{};

    if (status != null) filters['status'] = status;
    if (teamMember != null) {
      // Filter by team member in users child table
      filters['users'] = ['like', '%$teamMember%'];
    }

    final projects = await client.getList(
      'Project',
      fields: [
        'name',
        'project_name',
        'status',
        'percent_complete',
        'expected_start_date',
        'expected_end_date',
        'priority',
        'project_type',
      ],
      filters: filters,
      orderBy: 'expected_start_date desc',
    );

    return projects.map((p) => Project.fromJson(p)).toList();
  }

  // Get project details
  Future<Project> getProjectDetails(String projectId) async {
    final project = await client.getDoc(
      'Project',
      projectId,
      fields: [
        'name',
        'project_name',
        'status',
        'percent_complete',
        'expected_start_date',
        'expected_end_date',
        'actual_start_date',
        'actual_end_date',
        'priority',
        'project_type',
        'notes',
        'users',  // Team members child table
        'tasks',
      ],
    );

    return Project.fromJson(project);
  }

  // Create project
  Future<String> createProject(ProjectData data) async {
    final project = await client.createDoc(
      'Project',
      data: {
        'project_name': data.name,
        'status': 'Open',
        'expected_start_date': data.startDate,
        'expected_end_date': data.endDate,
        'priority': data.priority,
        'users': data.teamMembers.map((user) => {
          'user': user,
        }).toList(),
      },
    );

    return project['name'];
  }

  // Update project progress
  Future<void> updateProgress(String projectId, double progress) async {
    await client.updateDoc(
      'Project',
      projectId,
      data: {'percent_complete': progress},
    );
  }
}
```

### Task Service

```dart
class TaskService {
  final ShoutoutClient client;

  TaskService(this.client);

  // Get tasks
  Future<List<Task>> getTasks({
    String? projectId,
    String? assignedTo,
    String? status,
    String? priority,
  }) async {
    final filters = <String, dynamic>{};

    if (projectId != null) filters['project'] = projectId;
    if (assignedTo != null) filters['_assign'] = ['like', '%$assignedTo%'];
    if (status != null) filters['status'] = status;
    if (priority != null) filters['priority'] = priority;

    final tasks = await client.getList(
      'Task',
      fields: [
        'name',
        'subject',
        'project',
        'status',
        'priority',
        'exp_start_date',
        'exp_end_date',
        'progress',
        '_assign',
      ],
      filters: filters,
      orderBy: 'exp_start_date asc',
    );

    return tasks.map((t) => Task.fromJson(t)).toList();
  }

  // Create task
  Future<String> createTask(TaskData data) async {
    final task = await client.createDoc(
      'Task',
      data: {
        'subject': data.subject,
        'project': data.projectId,
        'status': 'Open',
        'priority': data.priority,
        'exp_start_date': data.startDate,
        'exp_end_date': data.endDate,
        'description': data.description,
      },
    );

    // Assign task
    if (data.assignedTo != null) {
      await assignTask(task['name'], data.assignedTo!);
    }

    return task['name'];
  }

  // Assign task
  Future<void> assignTask(String taskId, String userId) async {
    await client.callMethod(
      'frappe.desk.form.assign_to.add',
      params: {
        'doctype': 'Task',
        'name': taskId,
        'assign_to': [userId],
      },
    );
  }

  // Update task status
  Future<void> updateTaskStatus(String taskId, String status) async {
    await client.updateDoc(
      'Task',
      taskId,
      data: {'status': status},
    );
  }

  // Add comment to task
  Future<void> addComment(String taskId, String comment) async {
    await client.createDoc(
      'Comment',
      data: {
        'reference_doctype': 'Task',
        'reference_name': taskId,
        'comment_type': 'Comment',
        'content': comment,
      },
    );
  }
}
```

---

## Real Estate Platform

### Property Service

```dart
class PropertyService {
  final ShoutoutClient client;

  PropertyService(this.client);

  // Search properties
  Future<List<Property>> searchProperties({
    String? propertyType,
    String? city,
    double? minPrice,
    double? maxPrice,
    int? minBedrooms,
    int? minBathrooms,
    int page = 1,
  }) async {
    final filters = <String, dynamic>{
      'status': 'Available',
      'is_published': 1,
    };

    if (propertyType != null) filters['property_type'] = propertyType;
    if (city != null) filters['city'] = city;
    if (minPrice != null) filters['price'] = ['>=', minPrice];
    if (maxPrice != null) filters['price'] = ['<=', maxPrice];
    if (minBedrooms != null) filters['bedrooms'] = ['>=', minBedrooms];
    if (minBathrooms != null) filters['bathrooms'] = ['>=', minBathrooms];

    final properties = await client.getList(
      'Property',
      fields: [
        'name',
        'title',
        'property_type',
        'price',
        'city',
        'location',
        'bedrooms',
        'bathrooms',
        'area',
        'main_image',
        'is_featured',
      ],
      filters: filters,
      limitStart: (page - 1) * 20,
      limitPageLength: 20,
      orderBy: 'is_featured desc, modified desc',
    );

    return properties.map((p) => Property.fromJson(p)).toList();
  }

  // Get property details
  Future<Property> getPropertyDetails(String propertyId) async {
    final property = await client.getDoc(
      'Property',
      propertyId,
      fields: [
        'name',
        'title',
        'property_type',
        'price',
        'city',
        'location',
        'address',
        'latitude',
        'longitude',
        'bedrooms',
        'bathrooms',
        'area',
        'description',
        'main_image',
        'images',
        'amenities',
        'agent',
        'agent.agent_name',
        'agent.mobile',
        'agent.email',
      ],
    );

    return Property.fromJson(property);
  }

  // Schedule viewing
  Future<String> scheduleViewing({
    required String propertyId,
    required String customerId,
    required DateTime viewingDate,
    required String viewingTime,
    String? notes,
  }) async {
    final viewing = await client.createDoc(
      'Property Viewing',
      data: {
        'property': propertyId,
        'customer': customerId,
        'viewing_date': viewingDate.toIso8601String().split('T')[0],
        'viewing_time': viewingTime,
        'status': 'Scheduled',
        'notes': notes,
      },
    );

    return viewing['name'];
  }

  // Submit inquiry
  Future<void> submitInquiry({
    required String propertyId,
    required String customerName,
    required String email,
    required String phone,
    String? message,
  }) async {
    await client.createDoc(
      'Property Inquiry',
      data: {
        'property': propertyId,
        'customer_name': customerName,
        'email': email,
        'phone': phone,
        'message': message,
        'inquiry_date': DateTime.now().toIso8601String(),
      },
    );
  }

  // Get nearby properties
  Future<List<Property>> getNearbyProperties(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    final nearby = await client.callMethod<List>(
      'real_estate.api.get_nearby_properties',
      params: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
      },
    );

    return nearby.map((p) => Property.fromJson(p as Map<String, dynamic>)).toList();
  }
}
```

---

## Restaurant/Food Delivery

### Menu Service

```dart
class MenuService {
  final ShoutoutClient client;

  MenuService(this.client);

  // Get menu items
  Future<List<MenuItem>> getMenuItems({
    String? category,
    bool? isVegetarian,
    bool? isAvailable,
  }) async {
    final filters = <String, dynamic>{};

    if (category != null) filters['category'] = category;
    if (isVegetarian != null) filters['is_vegetarian'] = isVegetarian ? 1 : 0;
    if (isAvailable != null) filters['is_available'] = isAvailable ? 1 : 0;

    final items = await client.getList(
      'Menu Item',
      fields: [
        'name',
        'item_name',
        'description',
        'category',
        'price',
        'image',
        'is_vegetarian',
        'is_available',
        'preparation_time',
        'rating',
      ],
      filters: filters,
      orderBy: 'item_name asc',
    );

    return items.map((i) => MenuItem.fromJson(i)).toList();
  }

  // Get categories
  Future<List<String>> getCategories() async {
    final categories = await client.callMethod<List>(
      'frappe.client.get_list',
      params: {
        'doctype': 'Menu Category',
        'fields': ['name', 'category_name'],
      },
    );

    return categories
        .map((c) => (c as Map<String, dynamic>)['category_name'] as String)
        .toList();
  }
}
```

### Order Service

```dart
class FoodOrderService {
  final ShoutoutClient client;

  FoodOrderService(this.client);

  // Create order
  Future<String> createOrder(FoodOrderData data) async {
    final order = await client.createDoc(
      'Food Order',
      data: {
        'customer': data.customerId,
        'delivery_address': data.deliveryAddress,
        'items': data.items.map((item) => {
          'menu_item': item.menuItemId,
          'quantity': item.quantity,
          'rate': item.rate,
          'special_instructions': item.specialInstructions,
        }).toList(),
        'delivery_type': data.deliveryType, // Delivery or Pickup
        'payment_method': data.paymentMethod,
      },
    );

    return order['name'];
  }

  // Track order
  Future<OrderStatus> trackOrder(String orderId) async {
    final order = await client.getDoc(
      'Food Order',
      orderId,
      fields: [
        'name',
        'status',
        'delivery_status',
        'estimated_delivery_time',
        'assigned_driver',
        'assigned_driver.driver_name',
        'assigned_driver.mobile',
      ],
    );

    return OrderStatus.fromJson(order);
  }

  // Get order history
  Future<List<FoodOrder>> getOrderHistory(String customerId) async {
    final orders = await client.getList(
      'Food Order',
      fields: [
        'name',
        'creation',
        'status',
        'total_amount',
        'items',
      ],
      filters: {'customer': customerId},
      orderBy: 'creation desc',
      limitPageLength: 50,
    );

    return orders.map((o) => FoodOrder.fromJson(o)).toList();
  }

  // Rate order
  Future<void> rateOrder(String orderId, int rating, String? review) async {
    await client.updateDoc(
      'Food Order',
      orderId,
      data: {
        'rating': rating,
        'review': review,
      },
    );
  }
}
```

---

## Advanced Patterns

### 1. Repository Pattern

```dart
abstract class Repository<T> {
  final ShoutoutClient client;
  final String doctype;

  Repository(this.client, this.doctype);

  Future<List<T>> getAll({
    Map<String, dynamic>? filters,
    int? limit,
    String? orderBy,
  });

  Future<T> getById(String id);
  Future<T> create(Map<String, dynamic> data);
  Future<T> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

class UserRepository extends Repository<User> {
  UserRepository(ShoutoutClient client) : super(client, 'User');

  @override
  Future<List<User>> getAll({
    Map<String, dynamic>? filters,
    int? limit,
    String? orderBy,
  }) async {
    final users = await client.getList(
      doctype,
      fields: ['name', 'email', 'full_name'],
      filters: filters ?? {},
      limitPageLength: limit ?? 20,
      orderBy: orderBy ?? 'creation desc',
    );

    return users.map((u) => User.fromJson(u)).toList();
  }

  @override
  Future<User> getById(String id) async {
    final user = await client.getDoc(doctype, id);
    return User.fromJson(user);
  }

  @override
  Future<User> create(Map<String, dynamic> data) async {
    final user = await client.createDoc(doctype, data: data);
    return User.fromJson(user);
  }

  @override
  Future<User> update(String id, Map<String, dynamic> data) async {
    final user = await client.updateDoc(doctype, id, data: data);
    return User.fromJson(user);
  }

  @override
  Future<void> delete(String id) async {
    await client.deleteDoc(doctype, id);
  }
}
```

### 2. BLoC Integration

```dart
// Events
abstract class ProductEvent {}
class LoadProducts extends ProductEvent {}
class SearchProducts extends ProductEvent {
  final String query;
  SearchProducts(this.query);
}
class LoadMoreProducts extends ProductEvent {}

// States
abstract class ProductState {}
class ProductsLoading extends ProductState {}
class ProductsLoaded extends ProductState {
  final List<Product> products;
  final bool hasMore;
  ProductsLoaded(this.products, this.hasMore);
}
class ProductsError extends ProductState {
  final String message;
  ProductsError(this.message);
}

// BLoC
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductService productService;
  List<Product> _products = [];
  int _currentPage = 0;
  String? _searchQuery;

  ProductBloc(this.productService) : super(ProductsLoading()) {
    on<LoadProducts>(_onLoadProducts);
    on<SearchProducts>(_onSearchProducts);
    on<LoadMoreProducts>(_onLoadMoreProducts);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      _currentPage = 1;
      _products = await productService.getFeaturedProducts();
      emit(ProductsLoaded(_products, _products.length == 20));
    } on ShoutoutException catch (e) {
      emit(ProductsError(e.message));
    }
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      _searchQuery = event.query;
      _currentPage = 1;
      _products = await productService.searchProducts(
        event.query,
        page: _currentPage,
      );
      emit(ProductsLoaded(_products, _products.length == 20));
    } on ShoutoutException catch (e) {
      emit(ProductsError(e.message));
    }
  }

  Future<void> _onLoadMoreProducts(
    LoadMoreProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      _currentPage++;
      final newProducts = await productService.searchProducts(
        _searchQuery ?? '',
        page: _currentPage,
      );
      _products.addAll(newProducts);
      emit(ProductsLoaded(_products, newProducts.length == 20));
    } on ShoutoutException catch (e) {
      emit(ProductsError(e.message));
    }
  }
}
```

### 3. Caching Strategy

```dart
class CachedShoutoutService {
  final ShoutoutClient client;
  final Map<String, CacheEntry> _cache = {};
  final Duration cacheDuration;

  CachedShoutoutService(
    this.client, {
    this.cacheDuration = const Duration(minutes: 5),
  });

  Future<T> getDoc<T>(
    String doctype,
    String name, {
    List<String>? fields,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$doctype:$name';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired) {
        return entry.data as T;
      }
    }

    final data = await client.getDoc(doctype, name, fields: fields);
    _cache[cacheKey] = CacheEntry(data, DateTime.now().add(cacheDuration));
    return data as T;
  }

  void clearCache() {
    _cache.clear();
  }

  void invalidate(String doctype, String name) {
    _cache.remove('$doctype:$name');
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  CacheEntry(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
```

---

## Error Handling Strategies

### Comprehensive Error Handler

```dart
class ErrorHandler {
  static void handle(dynamic error, StackTrace stackTrace) {
    if (error is NetworkException) {
      _showError('No internet connection. Please check your network.');
    } else if (error is AuthenticationException) {
      _handleAuthError();
    } else if (error is AuthorizationException) {
      _showError('You do not have permission to perform this action.');
    } else if (error is NotFoundException) {
      _showError('The requested resource was not found.');
    } else if (error is TimeoutException) {
      _showError('Request timed out. Please try again.');
    } else if (error is ServerException) {
      _showError('Server error occurred. Please try again later.');
    } else if (error is FrappeException) {
      _showError(error.serverMessage ?? error.message);
    } else if (error is ShoutoutException) {
      _showError(error.message);
    } else {
      _showError('An unexpected error occurred.');
      _logError(error, stackTrace);
    }
  }

  static void _handleAuthError() {
    // Clear local auth
    // Navigate to login
    _showError('Your session has expired. Please login again.');
  }

  static void _showError(String message) {
    // Show snackbar or dialog
    print('Error: $message');
  }

  static void _logError(dynamic error, StackTrace stackTrace) {
    // Log to analytics/crashlytics
    print('Error: $error\n$stackTrace');
  }
}
```

---

## Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shoutout/shoutout.dart';

class MockShoutoutClient extends Mock implements ShoutoutClient {}

void main() {
  late MockShoutoutClient client;
  late ProductService service;

  setUp(() {
    client = MockShoutoutClient();
    service = ProductService(client);
  });

  group('ProductService', () {
    test('getFeaturedProducts returns list of products', () async {
      // Arrange
      when(() => client.getList(
            any(),
            fields: any(named: 'fields'),
            filters: any(named: 'filters'),
            limitPageLength: any(named: 'limitPageLength'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => [
            {
              'name': 'ITEM-001',
              'item_name': 'Test Product',
              'standard_rate': 100.0,
            }
          ]);

      // Act
      final products = await service.getFeaturedProducts();

      // Assert
      expect(products.length, 1);
      expect(products[0].name, 'ITEM-001');
      verify(() => client.getList(
            'Item',
            fields: any(named: 'fields'),
            filters: {'is_stock_item': 1, 'disabled': 0, 'featured': 1},
            limitPageLength: 20,
            orderBy: 'modified desc',
          )).called(1);
    });
  });
}
```

---

## Performance Optimization

### 1. Batch Requests

```dart
class BatchService {
  final ShoutoutClient client;

  BatchService(this.client);

  Future<List<Map<String, dynamic>>> batchGetDocs(
    List<DocReference> refs,
  ) async {
    final results = await Future.wait(
      refs.map((ref) => client.getDoc(
        ref.doctype,
        ref.name,
        fields: ref.fields,
      )),
    );

    return results;
  }
}

class DocReference {
  final String doctype;
  final String name;
  final List<String>? fields;

  DocReference(this.doctype, this.name, {this.fields});
}
```

### 2. Request Debouncing

```dart
class DebouncedSearch {
  final ProductService service;
  Timer? _debounce;

  DebouncedSearch(this.service);

  void search(String query, Function(List<Product>) onResults) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await service.searchProducts(query);
      onResults(results);
    });
  }

  void dispose() {
    _debounce?.cancel();
  }
}
```

---

This comprehensive guide covers multiple real-world scenarios and patterns for using Shoutout with Frappe/ERPNext! 🚀

## 9. Offline-First Architecture 📱

Shoutout v0.0.2+ includes comprehensive offline-first capabilities for mobile apps.

### Key Features

- **Network Monitoring**: Real-time connectivity detection with quality estimation
- **Offline Queue**: Automatic request queuing when offline
- **Cache Management**: Flexible caching with TTL support
- **Clean Architecture**: Failure pattern for error handling
- **Either/Result**: Functional error handling with dartz

### Network Monitoring Example

```dart
class NetworkAwareWidget extends StatefulWidget {
  @override
  _NetworkAwareWidgetState createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  final networkMonitor = NetworkMonitor();
  NetworkStatus? currentStatus;

  @override
  void initState() {
    super.initState();

    // Listen to network changes
    networkMonitor.statusStream.listen((status) {
      setState(() {
        currentStatus = status;
      });

      if (status.isConnected) {
        print('Online: ${status.connectionType}');
      } else {
        print('Offline - queue requests');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (currentStatus != null)
          ConnectionStatusBanner(status: currentStatus!),
      ],
    );
  }

  @override
  void dispose() {
    networkMonitor.dispose();
    super.dispose();
  }
}
```

### Offline Queue Manager Example

```dart
class DataSyncService {
  final ShoutoutClient client;
  late OfflineQueueManager queueManager;

  Future<void> initialize() async {
    queueManager = OfflineQueueManager(
      dio: client.dio,
      config: OfflineQueueConfig(
        autoSync: true,
        syncInterval: Duration(seconds: 30),
      ),
    );
    await queueManager.initialize();
  }

  Future<void> createTodoOffline(Map<String, dynamic> data) async {
    final request = QueuedRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST',
      url: '${client.config.baseUrl}/api/resource/ToDo',
      data: data,
      createdAt: DateTime.now(),
      priority: 10,
    );
    await queueManager.enqueue(request);
  }
}
```

### Cache Manager Example

```dart
class CachedDataService {
  final ShoutoutClient client;
  final CacheManager cacheManager = CacheManager();

  Future<void> initialize() async {
    await cacheManager.initialize();
  }

  // Cache-first strategy
  Future<List<dynamic>> getUsers({bool forceRefresh = false}) async {
    return await cacheManager.getOrFetch(
      'users_list',
      () => client.getList('User', fields: ['name', 'email']),
      expiresIn: Duration(minutes: 30),
      forceRefresh: forceRefresh,
    );
  }
}
```

### Using Failures (Clean Architecture)

```dart
class UserRepository {
  final ShoutoutClient client;

  Future<Either<Failure, List<User>>> getUsers() async {
    try {
      final response = await client.getList('User');
      final users = (response as List)
          .map((json) => User.fromJson(json))
          .toList();
      return Right(users);
    } on ShoutoutException catch (e) {
      return Left(e.toFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}

// In BLoC
class UserBloc extends Bloc<UserEvent, UserState> {
  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    emit(UserLoading());

    final result = await repository.getUsers();

    result.fold(
      (failure) => emit(UserError(message: failure.message)),
      (users) => emit(UserLoaded(users: users)),
    );
  }
}
```

### Complete Offline-First Example

```dart
class TodoService {
  final ShoutoutClient client;
  final CacheManager cache;
  final OfflineQueueManager queue;
  final NetworkMonitor network;

  Future<Either<Failure, List<Todo>>> getTodos() async {
    try {
      // Try cache first (works offline)
      final cached = await cache.get<List<Todo>>('todos');

      if (network.isDisconnected && cached != null) {
        return Right(cached);
      }

      // Fetch fresh data if online
      if (network.isConnected) {
        final response = await client.getList('ToDo');
        final todos = (response as List)
            .map((json) => Todo.fromJson(json))
            .toList();

        await cache.put('todos', todos, expiresIn: Duration(minutes: 15));
        return Right(todos);
      }

      // Offline without cache
      return Left(NetworkFailure());
    } on ShoutoutException catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, void>> createTodo(Todo todo) async {
    try {
      if (network.isConnected) {
        await client.createDoc('ToDo', data: todo.toJson());
      } else {
        // Queue for sync when online
        await queue.enqueueFromOptions(...);
      }

      await cache.delete('todos'); // Invalidate cache
      return const Right(null);
    } on ShoutoutException catch (e) {
      return Left(e.toFailure());
    }
  }
}
```

### Best Practices

1. **Always use Either<Failure, T>** for repository methods
2. **Cache aggressively** for offline support
3. **Queue write operations** when offline
4. **Listen to network changes** for automatic sync
5. **Show offline indicators** to users
6. **Invalidate cache** after writes
7. **Set appropriate TTL** for different data types
8. **Handle errors gracefully** with specific Failure types
9. **Test offline scenarios** thoroughly
10. **Monitor queue size** and handle failures

---

This comprehensive guide now covers real-world scenarios, advanced patterns, and complete offline-first architecture for using Shoutout with Frappe/ERPNext! 🚀
