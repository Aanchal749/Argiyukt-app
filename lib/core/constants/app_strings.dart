class AppStrings {
  static const Map<String, Map<String, String>> languages = {
    'en': {
      // --- COMMON ---
      'app_name': 'AgriYukt',
      'get_started': 'GET STARTED',
      'next': 'NEXT',
      'skip': 'SKIP',
      'login_caps': 'LOGIN',

      // --- LOGIN ---
      'login_title': 'AgriYukt Login',
      'email_phone': 'Email or Mobile Number',
      'password': 'Password',
      'forgot_pass': 'Forgot Password?',
      'login_btn': 'LOGIN',
      'no_account': 'Don\'t have an account? ',
      'create_acc': 'Create your account',

      // --- REGISTRATION HEADER ---
      'reg_title': 'Register', // CHANGED from "Create Account"
      'personal_details': 'Personal Details',
      'select_role': 'Select your Role',
      'reg_btn': 'Register Account',
      'already_have': 'Already have an account? ',
      'go_login': 'Login Here',

      // --- PERSONAL FIELDS ---
      'fname': 'First Name',
      'mname': 'Middle Name',
      'lname': 'Last Name',
      'email': 'Email Address',
      'mobile': 'Mobile Number',
      'pass': 'Password',
      'conf_pass': 'Confirm Password',

      // --- BUYER SPECIFIC ---
      'add_buyer': 'Additional Buyer Info',
      'biz_type': 'Business Type',
      'gst': 'GST Number (Optional)',

      // --- FARMER SPECIFIC ---
      'add_farmer': 'Additional Farmer Info',
      'farm_type': 'Farmer Type (Owner/Tenant)',
      'land_size': 'Land Size (Acres)',
      'farming_type': 'Farming Type', // Dropdown label

      // --- INSPECTOR SPECIFIC ---
      'add_inspector': 'Additional Inspector Info',
      'insp_cat': 'Inspector Category',
      'emp_type': 'Employee Type',
      'dept': 'Department',
      'org': 'Organization',
      'emp_id': 'Employee ID',

      // --- LOCATION DETAILS ---
      'loc_details': 'Location Details',
      'state': 'State',
      'district': 'District',
      'taluka': 'Taluka',
      'village': 'Village',
      'sub_village': 'Sub-village',
      'pin': 'PIN Code',

      // --- OTHER ---
      'role_farmer': 'Farmer',
      'role_buyer': 'Buyer',
      'role_inspector': 'Inspector',

      // Forgot Pass
      'forgot_title': 'Forgot Password',
      'reset_header': 'Reset Password',
      'reset_desc': 'Enter details to reset.',
      'send_link': 'SEND LINK',
      'link_sent': 'Link sent!',
      'error_prefix': 'Error: ',

      // Onboarding (Keep existing logic)
      'welcome_msg': 'Welcome to AgriYukt',
      'select_lang': 'Select your language',
      'slide1_title': 'Direct Demand & Supply',
      'slide1_desc': 'Real-time updates.',
      'slide2_title': '3 Role-Based System',
      'slide2_desc': 'Specialized tools.',
      'slide3_title': 'Trusted & Verified',
      'slide3_desc': 'Secure platform.',
    },
    'mr': {
      // --- COMMON ---
      'app_name': 'अ‍ॅग्रीयुक्त',
      'get_started': 'सुरू करा',
      'next': 'पुढे',
      'skip': 'वगळा',
      'login_caps': 'लॉगिन',

      // --- LOGIN ---
      'login_title': 'अग्रियुक्त लॉगिन',
      'email_phone': 'ईमेल किंवा मोबाईल नंबर',
      'password': 'पासवर्ड',
      'forgot_pass': 'पासवर्ड विसरलात?',
      'login_btn': 'लॉगिन',
      'no_account': 'खाते नाही? ',
      'create_acc': 'खाते तयार करा',

      // --- REGISTRATION HEADER ---
      'reg_title': 'नोंदणी', // "Register"
      'personal_details': 'वैयक्तिक माहिती',
      'select_role': 'आपली भूमिका निवडा',
      'reg_btn': 'खाते नोंदणी करा',
      'already_have': 'आधीच खाते आहे? ',
      'go_login': 'लॉगिन करा',

      // --- PERSONAL FIELDS ---
      'fname': 'पहिले नाव',
      'mname': 'मधले नाव',
      'lname': 'आडनाव',
      'email': 'ई-मेल पत्ता',
      'mobile': 'मोबाईल क्रमांक',
      'pass': 'पासवर्ड',
      'conf_pass': 'पासवर्ड पुन्हा टाका',

      // --- BUYER SPECIFIC ---
      'add_buyer': 'खरेदीदाराची अतिरिक्त माहिती',
      'biz_type': 'व्यवसायाचा प्रकार',
      'gst': 'जीएसटी क्रमांक (वैकल्पिक)',

      // --- FARMER SPECIFIC ---
      'add_farmer': 'शेतकऱ्याची अतिरिक्त माहिती',
      'farm_type': 'शेतकऱ्याचा प्रकार (मालक/कूळ)',
      'land_size': 'जमिनीचे क्षेत्रफळ (एकर)',
      'farming_type': 'शेतीचा प्रकार', // Dropdown

      // --- INSPECTOR SPECIFIC ---
      'add_inspector': 'निरीक्षकाची अतिरिक्त माहिती',
      'insp_cat': 'निरीक्षक श्रेणी',
      'emp_type': 'कर्मचारी प्रकार',
      'dept': 'विभाग',
      'org': 'संस्था / कंपनी',
      'emp_id': 'कर्मचारी ओळख क्रमांक',

      // --- LOCATION DETAILS ---
      'loc_details': 'पत्ता / ठिकाण तपशील',
      'state': 'राज्य',
      'district': 'जिल्हा',
      'taluka': 'तालुका',
      'village': 'गाव',
      'sub_village': 'वाडी / वस्ती',
      'pin': 'पिन कोड',

      // --- OTHER ---
      'role_farmer': 'शेतकरी',
      'role_buyer': 'खरेदीदार',
      'role_inspector': 'निरीक्षक',

      // Forgot Pass
      'forgot_title': 'पासवर्ड विसरलात',
      'reset_header': 'पासवर्ड रीसेट करा',
      'reset_desc': 'माहिती भरा.',
      'send_link': 'लिंक पाठवा',
      'link_sent': 'लिंक पाठवली आहे!',
      'error_prefix': 'त्रुटी: ',

      // Onboarding
      'welcome_msg': 'अग्रियुक्त मध्ये आपले स्वागत आहे',
      'select_lang': 'आपली भाषा निवडा',
      'slide1_title': 'थेट मागणी व पुरवठा',
      'slide1_desc': 'थेट मार्केटशी जोडा.',
      'slide2_title': '३ भूमिकांची प्रणाली',
      'slide2_desc': 'खास टूल्स.',
      'slide3_title': 'विश्वास व पडताळणी',
      'slide3_desc': 'सुरक्षित व्यवहार.',
    }
  };
}
//cd %LOCALAPPDATA%\Android\Sdk\platform-tools
//adb tcpip 5555
//adb connect 192.168.137.217:5555
