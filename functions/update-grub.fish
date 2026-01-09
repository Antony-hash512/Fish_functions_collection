function update-grub --description "Упрощённая команда для обновления Grub2 как в Ubuntu"
    sudo grub-mkconfig -o /boot/grub/grub.cfg
end
