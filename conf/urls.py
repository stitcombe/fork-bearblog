from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import RedirectView


urlpatterns = [
    path('mothership/', admin.site.urls),
    path('accounts/', include('allauth.urls')),
    path('', include('blogs.urls')),
]

if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [
        path('__debug__/', include(debug_toolbar.urls)),
    ] + urlpatterns

# Serve media files in development or self-hosted mode
if settings.DEBUG or getattr(settings, 'SELF_HOSTED', False):
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

handler404 = 'blogs.views.blog.not_found'
