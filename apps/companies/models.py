from django.db import models


class Company(models.Model):
    name = models.CharField(max_length=200)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "Companies"


class Site(models.Model):
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="sites")
    name = models.CharField(max_length=200)
    address = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.company.name} - {self.name}"


class EquipmentCategory(models.Model):
    """მოწყობილობის კატეგორია - დაჯგუფებისთვის"""
    
    SYSTEM_CHOICES = [
        ("hvac", "გათბობა/გაგრილება (HVAC)"),
        ("ventilation", "ვენტილაცია"),
        ("refrigeration", "სამაცივრო"),
        ("electrical", "ელექტრო"),
        ("plumbing", "სანტექნიკა"),
        ("other", "სხვა"),
    ]
    
    name = models.CharField(max_length=100, verbose_name="კატეგორიის სახელი")
    code = models.CharField(max_length=20, unique=True, verbose_name="კოდი")
    system_type = models.CharField(
        max_length=50, 
        choices=SYSTEM_CHOICES, 
        default="hvac",
        verbose_name="სისტემის ტიპი"
    )
    icon = models.CharField(
        max_length=50, 
        default="bi-gear", 
        verbose_name="Icon Class",
        help_text="Bootstrap Icons კლასი, მაგ: bi-fan, bi-thermometer"
    )
    color = models.CharField(
        max_length=20, 
        default="#6c757d",
        verbose_name="ფერი",
        help_text="HEX ფერი, მაგ: #ff5733"
    )
    description = models.TextField(blank=True, verbose_name="აღწერა")
    display_order = models.PositiveIntegerField(default=0, verbose_name="თანმიმდევრობა")
    
    def __str__(self):
        return self.name
    
    class Meta:
        verbose_name = "კატეგორია"
        verbose_name_plural = "კატეგორიები"
        ordering = ["display_order", "name"]


class Equipment(models.Model):
    SYSTEM_CHOICES = [
        ("heating_cooling", "გათბობა/გაგრილება"),
        ("ventilation", "ვენტილაცია"),
    ]
    
    STATUS_CHOICES = [
        ("active", "აქტიური"),
        ("inactive", "არააქტიური"),
        ("maintenance", "მომსახურებაში"),
        ("broken", "გაფუჭებული"),
    ]

    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name="equipment")
    category = models.ForeignKey(
        EquipmentCategory, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name="equipment",
        verbose_name="კატეგორია"
    )
    name = models.CharField(max_length=200, verbose_name="სახელი")
    brand = models.CharField(max_length=100, blank=True, verbose_name="ბრენდი")
    model_number = models.CharField(max_length=100, blank=True, verbose_name="მოდელი")
    serial_number = models.CharField(max_length=100, blank=True, verbose_name="სერიული ნომერი")
    system_type = models.CharField(max_length=50, choices=SYSTEM_CHOICES, verbose_name="სისტემის ტიპი")
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default="active",
        verbose_name="სტატუსი"
    )
    location_detail = models.CharField(
        max_length=200, 
        blank=True,
        verbose_name="ზუსტი მდებარეობა",
        help_text="მაგ: სახურავი, სარდაფი, მე-2 სართული"
    )
    installation_date = models.DateField(null=True, blank=True, verbose_name="ინსტალაციის თარიღი")
    warranty_end = models.DateField(null=True, blank=True, verbose_name="გარანტიის ვადა")
    notes = models.TextField(blank=True, verbose_name="შენიშვნები")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.site.name} - {self.name}"
    
    @property
    def is_under_warranty(self):
        """გარანტია მოქმედია?"""
        from django.utils import timezone
        if self.warranty_end:
            return self.warranty_end >= timezone.now().date()
        return False

    class Meta:
        verbose_name = "მოწყობილობა"
        verbose_name_plural = "მოწყობილობები"
        ordering = ["site", "category", "name"]
