class AppUser {
  final int id;
  final String username;
  final String email;
  final String role;
  final String phone;
  final String firstName;
  final String lastName;
  final int? tenantId;
  final String? tenantName;
  final int? companyId;
  final String? companyName;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.tenantId,
    this.tenantName,
    this.companyId,
    this.companyName,
  });

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  String get roleDisplay {
    switch (role) {
      case 'manager':
        return 'მენეჯერი';
      case 'inspector':
        return 'ინსპექტორი';
      case 'client':
        return 'კლიენტი';
      default:
        return role;
    }
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'client',
      phone: json['phone'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      tenantId: json['tenant'],
      tenantName: json['tenant_name'],
      companyId: json['company'],
      companyName: json['company_name'],
    );
  }
}

class CompanyModel {
  final int id;
  final String name;
  final int sitesCount;
  final int equipmentCount;
  final String createdAt;

  CompanyModel({
    required this.id,
    required this.name,
    required this.sitesCount,
    required this.equipmentCount,
    required this.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sitesCount: json['sites_count'] ?? 0,
      equipmentCount: json['equipment_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class SiteModel {
  final int id;
  final int companyId;
  final String companyName;
  final String name;
  final String address;
  final int equipmentCount;
  final String createdAt;

  SiteModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.name,
    required this.address,
    required this.equipmentCount,
    required this.createdAt,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    return SiteModel(
      id: json['id'] ?? 0,
      companyId: json['company'] ?? 0,
      companyName: json['company_name'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      equipmentCount: json['equipment_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class CategoryModel {
  final int id;
  final String name;
  final String code;
  final String systemType;
  final String icon;
  final String color;
  final String description;
  final int displayOrder;
  final int equipmentCount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.code,
    required this.systemType,
    required this.icon,
    required this.color,
    required this.description,
    required this.displayOrder,
    required this.equipmentCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      systemType: json['system_type'] ?? 'hvac',
      icon: json['icon'] ?? 'bi-gear',
      color: json['color'] ?? '#6c757d',
      description: json['description'] ?? '',
      displayOrder: json['display_order'] ?? 0,
      equipmentCount: json['equipment_count'] ?? 0,
    );
  }
}

class EquipmentModel {
  final int id;
  final int siteId;
  final String siteName;
  final int companyId;
  final String companyName;
  final int? categoryId;
  final String? categoryName;
  final String categoryColor;
  final String categoryIcon;
  final String name;
  final String brand;
  final String modelNumber;
  final String serialNumber;
  final String systemType;
  final String systemTypeDisplay;
  final String status;
  final String statusDisplay;
  final String locationDetail;
  final String? installationDate;
  final String? warrantyEnd;
  final bool isUnderWarranty;
  final String notes;

  EquipmentModel({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.companyId,
    required this.companyName,
    this.categoryId,
    this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.name,
    required this.brand,
    required this.modelNumber,
    required this.serialNumber,
    required this.systemType,
    required this.systemTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.locationDetail,
    this.installationDate,
    this.warrantyEnd,
    required this.isUnderWarranty,
    required this.notes,
  });

  factory EquipmentModel.fromJson(Map<String, dynamic> json) {
    return EquipmentModel(
      id: json['id'] ?? 0,
      siteId: json['site'] ?? 0,
      siteName: json['site_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      categoryId: json['category'],
      categoryName: json['category_name'],
      categoryColor: json['category_color'] ?? '#6c757d',
      categoryIcon: json['category_icon'] ?? 'bi-gear',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      modelNumber: json['model_number'] ?? '',
      serialNumber: json['serial_number'] ?? '',
      systemType: json['system_type'] ?? 'heating_cooling',
      systemTypeDisplay: json['system_type_display'] ?? '',
      status: json['status'] ?? 'active',
      statusDisplay: json['status_display'] ?? '',
      locationDetail: json['location_detail'] ?? '',
      installationDate: json['installation_date'],
      warrantyEnd: json['warranty_end'],
      isUnderWarranty: json['is_under_warranty'] ?? false,
      notes: json['notes'] ?? '',
    );
  }
}

class ScheduleModel {
  final int id;
  final int equipmentId;
  final String equipmentName;
  final int siteId;
  final String siteName;
  final int companyId;
  final String companyName;
  final String taskName;
  final String frequency;
  final String frequencyDisplay;

  ScheduleModel({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.siteId,
    required this.siteName,
    required this.companyId,
    required this.companyName,
    required this.taskName,
    required this.frequency,
    required this.frequencyDisplay,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] ?? 0,
      equipmentId: json['equipment'] ?? 0,
      equipmentName: json['equipment_name'] ?? '',
      siteId: json['site_id'] ?? 0,
      siteName: json['site_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      taskName: json['task_name'] ?? '',
      frequency: json['frequency'] ?? 'monthly',
      frequencyDisplay: json['frequency_display'] ?? '',
    );
  }
}

class TaskPhotoModel {
  final int id;
  final String imageUrl;
  final String? uploadedAt;

  TaskPhotoModel({
    required this.id,
    required this.imageUrl,
    this.uploadedAt,
  });

  factory TaskPhotoModel.fromJson(Map<String, dynamic> json) {
    return TaskPhotoModel(
      id: json['id'] ?? 0,
      imageUrl: json['image'] ?? '',
      uploadedAt: json['uploaded_at'],
    );
  }
}

class TaskReportModel {
  final int id;
  final String comment;
  final String? createdAt;
  final List<TaskPhotoModel> photos;

  TaskReportModel({
    required this.id,
    required this.comment,
    this.createdAt,
    required this.photos,
  });

  factory TaskReportModel.fromJson(Map<String, dynamic> json) {
    final photosList = (json['photos'] as List<dynamic>? ?? [])
        .map((p) => TaskPhotoModel.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    return TaskReportModel(
      id: json['id'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'],
      photos: photosList,
    );
  }
}

class TaskModel {
  final int id;
  final int? scheduleId;
  final String scheduleName;
  final String frequency;
  final String frequencyDisplay;
  final int? equipmentId;
  final String equipmentName;
  final int? siteId;
  final String siteName;
  final int? companyId;
  final String companyName;
  final int? assignedToId;
  final String? assignedToName;
  final String? assignedToFullName;
  final String status;
  final String statusDisplay;
  final String scheduledDate;
  final String? completedDate;
  final String? createdAt;
  final TaskReportModel? report;

  TaskModel({
    required this.id,
    this.scheduleId,
    required this.scheduleName,
    required this.frequency,
    required this.frequencyDisplay,
    this.equipmentId,
    required this.equipmentName,
    this.siteId,
    required this.siteName,
    this.companyId,
    required this.companyName,
    this.assignedToId,
    this.assignedToName,
    this.assignedToFullName,
    required this.status,
    required this.statusDisplay,
    required this.scheduledDate,
    this.completedDate,
    this.createdAt,
    this.report,
  });

  String get inspectorDisplay =>
      (assignedToFullName != null && assignedToFullName!.isNotEmpty)
          ? assignedToFullName!
          : (assignedToName ?? '-');

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? 0,
      scheduleId: json['schedule'],
      scheduleName: json['schedule_name'] ?? '',
      frequency: json['frequency'] ?? '',
      frequencyDisplay: json['frequency_display'] ?? '',
      equipmentId: json['equipment_id'],
      equipmentName: json['equipment_name'] ?? '',
      siteId: json['site_id'],
      siteName: json['site_name'] ?? '',
      companyId: json['company_id'],
      companyName: json['company_name'] ?? '',
      assignedToId: json['assigned_to'] ?? json['assigned_to_id'],
      assignedToName: json['assigned_to_name'],
      assignedToFullName: json['assigned_to_full_name'],
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? '',
      scheduledDate: json['scheduled_date'] ?? '',
      completedDate: json['completed_date'],
      createdAt: json['created_at'],
      report: json['report'] != null
          ? TaskReportModel.fromJson(Map<String, dynamic>.from(json['report']))
          : null,
    );
  }
}

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final String link;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.link,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      link: json['link'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PickedPhotoFile {
  final String name;
  final List<int> bytes;

  PickedPhotoFile({required this.name, required this.bytes});
}
