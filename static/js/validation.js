/**
 * Georgian Form Validation
 * Provides custom validation messages in Georgian language
 */

const validationMessages = {
    required: 'ეს ველი აუცილებელია',
    email: 'გთხოვთ შეიყვანეთ სწორი ელ-ფოსტა',
    minLength: (length) => `მინიმუმ ${length} სიმბოლო საჭიროა`,
    maxLength: (length) => `მაქსიმუმ ${length} სიმბოლო დასაშვებია`,
    pattern: 'მნიშვნელობა არ შეესაბამება ნიმუშს',
    number: 'გთხოვთ შეიყვანეთ რიცხვი',
    duplicate: 'ეს მნიშვნელობა უკვე გამოიყენება',
    unique: 'ეს მნიშვნელობა უკვე არსებობს',
};

/**
 * Validate a form with Georgian error messages
 */
function validateForm(formElement) {
    const inputs = formElement.querySelectorAll('input[required], textarea[required], select[required]');
    let isValid = true;

    inputs.forEach(input => {
        removeErrorMessage(input);
        
        if (!input.value.trim()) {
            showErrorMessage(input, validationMessages.required);
            isValid = false;
        } else if (input.type === 'email' && !isValidEmail(input.value)) {
            showErrorMessage(input, validationMessages.email);
            isValid = false;
        } else if (input.minLength > 0 && input.value.length < input.minLength) {
            showErrorMessage(input, validationMessages.minLength(input.minLength));
            isValid = false;
        } else if (input.maxLength > 0 && input.value.length > input.maxLength) {
            showErrorMessage(input, validationMessages.maxLength(input.maxLength));
            isValid = false;
        }
    });

    return isValid;
}

/**
 * Show error message below input
 */
function showErrorMessage(element, message) {
    // Remove existing error if any
    removeErrorMessage(element);

    // Create error message element
    const errorDiv = document.createElement('div');
    errorDiv.className = 'invalid-feedback d-block mt-1 text-danger';
    errorDiv.textContent = message;
    
    element.classList.add('is-invalid');
    element.parentNode.appendChild(errorDiv);
}

/**
 * Remove error message
 */
function removeErrorMessage(element) {
    element.classList.remove('is-invalid');
    const existingError = element.parentNode.querySelector('.invalid-feedback');
    if (existingError) {
        existingError.remove();
    }
}

/**
 * Validate email format
 */
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

/**
 * Setup form validation for all forms on page
 */
document.addEventListener('DOMContentLoaded', function() {
    const forms = document.querySelectorAll('form');
    
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            if (!validateForm(this)) {
                e.preventDefault();
                e.stopPropagation();
            }
        });

        // Clear error on input change
        const inputs = form.querySelectorAll('input[required], textarea[required], select[required]');
        inputs.forEach(input => {
            input.addEventListener('change', function() {
                removeErrorMessage(this);
            });
        });
    });
});
